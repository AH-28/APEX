import { randomUUID } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import type { FastifyInstance } from 'fastify';
import type { DB } from '../db.js';
import { requireAuth, type AuthedUser } from '../auth.js';
import { getOrGenerateDailyQuests, type QuestRow } from '../services/questGenerator.js';
import { config } from '../config.js';

const UPLOAD_DIR = 'uploads';

function toApi(q: QuestRow) {
  return {
    id: q.id,
    date: q.quest_date,
    title: q.title,
    description: q.description,
    category: q.category,
    difficulty: q.difficulty,
    xpReward: q.xp_reward,
    estMinutes: q.est_minutes,
    requiresPhoto: q.requires_photo === 1,
    status: q.status,
    completedAt: q.completed_at,
    hasPhoto: q.photo_path != null,
  };
}

export function questRoutes(app: FastifyInstance, db: DB) {
  // Today's quests — lazily generates them on first call of the day.
  app.get('/quests/today', { preHandler: requireAuth }, async (req) => {
    const { id } = (req as typeof req & { user: AuthedUser }).user;
    const quests = await getOrGenerateDailyQuests(db, id);
    return { quests: quests.map(toApi) };
  });

  // History (completed quests = the memory journal).
  app.get<{ Querystring: { limit?: number } }>(
    '/quests/history',
    { preHandler: requireAuth },
    async (req) => {
      const { id } = (req as typeof req & { user: AuthedUser }).user;
      const limit = Math.min(Number(req.query.limit ?? 50), 200);
      const rows = db
        .prepare(
          `SELECT * FROM quests WHERE user_id = ? AND status = 'completed'
           ORDER BY completed_at DESC LIMIT ?`,
        )
        .all(id, limit) as QuestRow[];
      return { quests: rows.map(toApi) };
    },
  );

  // Complete a quest. Optional base64 photo proof.
  app.post<{ Params: { id: string }; Body: { photoBase64?: string } | null }>(
    '/quests/:id/complete',
    { preHandler: requireAuth },
    async (req, reply) => {
      const { id: userId } = (req as typeof req & { user: AuthedUser }).user;
      const quest = db
        .prepare('SELECT * FROM quests WHERE id = ? AND user_id = ?')
        .get(req.params.id, userId) as QuestRow | undefined;
      if (!quest) return reply.code(404).send({ error: 'quest not found' });
      if (quest.status === 'completed') return reply.code(409).send({ error: 'quest already completed' });

      let photoPath: string | null = null;
      const photoBase64 = req.body?.photoBase64;
      if (photoBase64) {
        const bytes = Buffer.from(photoBase64, 'base64');
        if (bytes.length > 10 * 1024 * 1024) return reply.code(413).send({ error: 'photo too large (max 10MB)' });
        mkdirSync(UPLOAD_DIR, { recursive: true });
        photoPath = join(UPLOAD_DIR, `${quest.id}-${randomUUID()}.jpg`);
        writeFileSync(photoPath, bytes);
      }

      const result = db.transaction(() => {
        db.prepare(
          `UPDATE quests SET status = 'completed', completed_at = datetime('now'), photo_path = ? WHERE id = ?`,
        ).run(photoPath, quest.id);
        db.prepare('UPDATE users SET xp = xp + ? WHERE id = ?').run(quest.xp_reward, userId);
        // Recompute level from total XP.
        const { xp } = db.prepare('SELECT xp FROM users WHERE id = ?').get(userId) as { xp: number };
        const level = Math.floor(xp / config.xpPerLevel) + 1;
        db.prepare('UPDATE users SET level = ? WHERE id = ?').run(level, userId);
        return { xp, level };
      })();

      return { ok: true, xpAwarded: quest.xp_reward, totalXp: result.xp, level: result.level };
    },
  );

  // Skip a quest (no XP, frees up the slot psychologically; history still avoids repeats).
  app.post<{ Params: { id: string } }>(
    '/quests/:id/skip',
    { preHandler: requireAuth },
    async (req, reply) => {
      const { id: userId } = (req as typeof req & { user: AuthedUser }).user;
      const changed = db
        .prepare(`UPDATE quests SET status = 'skipped' WHERE id = ? AND user_id = ? AND status = 'active'`)
        .run(req.params.id, userId);
      if (changed.changes === 0) return reply.code(404).send({ error: 'active quest not found' });
      return { ok: true };
    },
  );
}
