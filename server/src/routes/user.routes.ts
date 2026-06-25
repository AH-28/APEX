import type { FastifyInstance } from 'fastify';
import type { DB } from '../db.js';
import { requireAuth, type AuthedUser } from '../auth.js';
import { CATEGORIES } from '../seed/templates.js';
import { config } from '../config.js';

const AGE_RANGES = ['13-17', '18-24', '25-34', '35-49', '50+'];

export function userRoutes(app: FastifyInstance, db: DB) {
  app.get('/me', { preHandler: requireAuth }, async (req) => {
    const { id } = (req as typeof req & { user: AuthedUser }).user;
    const u = db
      .prepare('SELECT id, email, display_name, xp, level, interests, difficulty, location, age_range, timezone FROM users WHERE id = ?')
      .get(id) as Record<string, unknown>;
    return { ...u, interests: JSON.parse(u.interests as string), xpPerLevel: config.xpPerLevel };
  });

  app.patch<{
    Body: {
      displayName?: string;
      interests?: string[];
      difficulty?: 'Easy' | 'Medium' | 'Hard';
      location?: string | null;
      ageRange?: string | null;
      timezone?: string;
    };
  }>('/me', { preHandler: requireAuth }, async (req, reply) => {
    const { id } = (req as typeof req & { user: AuthedUser }).user;
    const b = req.body;

    if (b.interests && b.interests.some((i) => !(CATEGORIES as readonly string[]).includes(i))) {
      return reply.code(400).send({ error: `interests must be from: ${CATEGORIES.join(', ')}` });
    }
    if (b.difficulty && !['Easy', 'Medium', 'Hard'].includes(b.difficulty)) {
      return reply.code(400).send({ error: 'difficulty must be Easy, Medium or Hard' });
    }
    if (b.ageRange != null && b.ageRange !== '' && !AGE_RANGES.includes(b.ageRange)) {
      return reply.code(400).send({ error: `ageRange must be one of: ${AGE_RANGES.join(', ')}` });
    }

    db.prepare(
      `UPDATE users SET
         display_name = COALESCE(?, display_name),
         interests    = COALESCE(?, interests),
         difficulty   = COALESCE(?, difficulty),
         location     = COALESCE(?, location),
         age_range    = COALESCE(?, age_range),
         timezone     = COALESCE(?, timezone)
       WHERE id = ?`,
    ).run(
      b.displayName ?? null,
      b.interests ? JSON.stringify(b.interests) : null,
      b.difficulty ?? null,
      b.location ?? null,
      b.ageRange ?? null,
      b.timezone ?? null,
      id,
    );
    return { ok: true };
  });

  app.get('/categories', async () => ({ categories: CATEGORIES }));
}
