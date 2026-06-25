// Quest Generation Service — the heart of APEX.
//
// Pipeline (per user, per day; idempotent via generation_runs):
//   1. Load user profile + recent quest history (14 days).
//   2. SELECT 3-5 templates:
//        - exclude templates used within the cooldown window (7 days)
//        - exclude age-gated / situationally wrong templates
//        - weighted random favouring the user's interest categories,
//          with a category-diversity cap (max 1 quest per category per day)
//        - difficulty mix anchored to the user's preference
//   3. FILL variables + titles via AI (single Claude call, structured output),
//      with deterministic fallback.
//   4. RENDER pattern → description, compute XP server-side, validate.
//   5. PERSIST quests + the generation run.

import { randomUUID } from 'node:crypto';
import type { DB } from '../db.js';
import { config } from '../config.js';
import { fillTemplates, type FilledQuest, type UserContext } from './aiFiller.js';
import type { QuestTemplate, TemplateVariable } from '../seed/templates.js';

export interface UserRow {
  id: string;
  email: string;
  xp: number;
  level: number;
  interests: string;
  difficulty: 'Easy' | 'Medium' | 'Hard';
  location: string | null;
  age_range: string | null;
  timezone: string;
}

export interface QuestRow {
  id: string;
  user_id: string;
  template_id: string;
  quest_date: string;
  title: string;
  description: string;
  category: string;
  difficulty: string;
  xp_reward: number;
  est_minutes: number;
  requires_photo: number;
  variables: string;
  status: string;
  completed_at: string | null;
  photo_path: string | null;
}

/** Today's date (YYYY-MM-DD) in the user's timezone. */
export function localDate(timezone: string, now = new Date()): string {
  try {
    return new Intl.DateTimeFormat('en-CA', { timeZone: timezone }).format(now);
  } catch {
    return new Intl.DateTimeFormat('en-CA', { timeZone: 'UTC' }).format(now);
  }
}

/** Idempotent: returns existing quests if today's were already generated. */
export async function getOrGenerateDailyQuests(db: DB, userId: string): Promise<QuestRow[]> {
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId) as UserRow | undefined;
  if (!user) throw new Error('user not found');
  const date = localDate(user.timezone);

  const existing = db
    .prepare('SELECT * FROM quests WHERE user_id = ? AND quest_date = ? ORDER BY created_at')
    .all(userId, date) as QuestRow[];
  if (existing.length > 0) return existing;

  return generateDailyQuests(db, user, date);
}

export async function generateDailyQuests(db: DB, user: UserRow, date: string): Promise<QuestRow[]> {
  // ── 1. History for repetition avoidance ─────────────────────────
  const history = db
    .prepare(
      `SELECT template_id, title, variables FROM quests
       WHERE user_id = ? AND quest_date >= date(?, '-' || ? || ' days')`,
    )
    .all(user.id, date, config.historyDays) as Pick<QuestRow, 'template_id' | 'title' | 'variables'>[];

  const recentTemplateIds = new Set(
    (db
      .prepare(
        `SELECT DISTINCT template_id FROM quests
         WHERE user_id = ? AND quest_date >= date(?, '-' || ? || ' days')`,
      )
      .all(user.id, date, config.templateCooldownDays) as { template_id: string }[]).map((r) => r.template_id),
  );

  // recently used titles + variable values per template (fed to the AI to avoid)
  const recentlyUsed: Record<string, string[]> = {};
  for (const h of history) {
    const values = Object.values(JSON.parse(h.variables) as Record<string, string>);
    recentlyUsed[h.template_id] = [...(recentlyUsed[h.template_id] ?? []), h.title, ...values];
  }

  // ── 2. Template selection ───────────────────────────────────────
  const allTemplates = loadTemplates(db);
  const interests: string[] = JSON.parse(user.interests);
  const count = pickQuestCount(user.level);
  const selected = selectTemplates(allTemplates, {
    interests,
    difficulty: user.difficulty,
    ageRange: user.age_range,
    exclude: recentTemplateIds,
    count,
  });

  // ── 3. AI fill ──────────────────────────────────────────────────
  const userCtx: UserContext = {
    interests,
    difficulty: user.difficulty,
    level: user.level,
    location: user.location,
    ageRange: user.age_range,
  };
  const { quests: filled, source } = await fillTemplates({ user: userCtx, templates: selected, recentlyUsed });

  // ── 4 & 5. Render, validate, persist ────────────────────────────
  const byId = new Map(selected.map((t) => [t.id, t]));
  const insert = db.prepare(`
    INSERT INTO quests (id, user_id, template_id, quest_date, title, description, category,
                        difficulty, xp_reward, est_minutes, requires_photo, variables)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  const markRun = db.prepare(
    'INSERT OR IGNORE INTO generation_runs (user_id, quest_date, quest_count, source) VALUES (?, ?, ?, ?)',
  );

  const rows: QuestRow[] = [];
  const tx = db.transaction(() => {
    for (const f of filled) {
      const t = byId.get(f.templateId);
      if (!t) continue;
      const description = renderPattern(t.pattern, f.variables);
      if (description.includes('{')) continue; // unfilled slot — drop rather than ship broken text
      const id = randomUUID();
      insert.run(
        id, user.id, t.id, date,
        f.title, description, t.category, t.difficulty,
        xpFor(t.difficulty, t.estMinutes), t.estMinutes, t.requiresPhoto ? 1 : 0,
        JSON.stringify(f.variables),
      );
      rows.push(db.prepare('SELECT * FROM quests WHERE id = ?').get(id) as QuestRow);
    }
    markRun.run(user.id, date, rows.length, source);
  });
  tx();
  return rows;
}

function loadTemplates(db: DB): QuestTemplate[] {
  const rows = db.prepare('SELECT * FROM quest_templates WHERE active = 1').all() as {
    id: string; category: string; pattern: string; title_hint: string; variables: string;
    difficulty: 'Easy' | 'Medium' | 'Hard'; est_minutes: number; requires_photo: number;
    indoor_ok: number; min_age_range: string | null;
  }[];
  return rows.map((r) => ({
    id: r.id,
    category: r.category as QuestTemplate['category'],
    pattern: r.pattern,
    titleHint: r.title_hint,
    variables: JSON.parse(r.variables) as Record<string, TemplateVariable>,
    difficulty: r.difficulty,
    estMinutes: r.est_minutes,
    requiresPhoto: r.requires_photo === 1,
    indoorOk: r.indoor_ok === 1,
    minAgeRange: r.min_age_range ?? undefined,
  }));
}

/** 5 quests for new users, scaling to 8 as they level up. */
export function pickQuestCount(level: number): number {
  if (level >= 10) return 8;
  if (level >= 4) return 6;
  return 5;
}

export interface SelectionOptions {
  interests: string[];
  difficulty: 'Easy' | 'Medium' | 'Hard';
  ageRange: string | null;
  exclude: Set<string>;
  count: number;
}

/**
 * Weighted random selection with category diversity.
 * Interest-matching categories get 3x weight; difficulty matching the user's
 * preference gets 2x; one step away gets 1x; two steps away gets 0.25x.
 */
export function selectTemplates(all: QuestTemplate[], opts: SelectionOptions): QuestTemplate[] {
  const diffRank = { Easy: 0, Medium: 1, Hard: 2 } as const;
  let pool = all.filter((t) => !opts.exclude.has(t.id) && ageOk(t.minAgeRange, opts.ageRange));
  // If cooldown excluded too much (small catalogue / power user), relax it.
  if (pool.length < opts.count) {
    pool = all.filter((t) => ageOk(t.minAgeRange, opts.ageRange));
  }

  const weight = (t: QuestTemplate): number => {
    const interestW = opts.interests.includes(t.category) ? 3 : 1;
    const dd = Math.abs(diffRank[t.difficulty] - diffRank[opts.difficulty]);
    const diffW = dd === 0 ? 2 : dd === 1 ? 1 : 0.25;
    return interestW * diffW;
  };

  const picked: QuestTemplate[] = [];
  const usedCategories = new Set<string>();
  let candidates = [...pool];
  while (picked.length < opts.count && candidates.length > 0) {
    // Prefer unused categories; fall back to the full pool if that empties.
    let round = candidates.filter((t) => !usedCategories.has(t.category));
    if (round.length === 0) round = candidates;
    const total = round.reduce((s, t) => s + weight(t), 0);
    let r = Math.random() * total;
    let chosen = round[round.length - 1];
    for (const t of round) {
      r -= weight(t);
      if (r <= 0) { chosen = t; break; }
    }
    picked.push(chosen);
    usedCategories.add(chosen.category);
    candidates = candidates.filter((t) => t.id !== chosen.id);
  }
  return picked;
}

function ageOk(minAgeRange: string | undefined, userAgeRange: string | null): boolean {
  if (!minAgeRange) return true;
  if (!userAgeRange) return false; // age-gated content needs a declared age range
  const order = ['13-17', '18-24', '25-34', '35-49', '50+'];
  return order.indexOf(userAgeRange) >= order.indexOf(minAgeRange);
}

export function renderPattern(pattern: string, variables: Record<string, string>): string {
  return pattern.replace(/\{(\w+)\}/g, (m, name: string) => variables[name] ?? m);
}

/** XP is computed server-side only — the AI never sets rewards. */
export function xpFor(difficulty: string, estMinutes: number): number {
  const base = config.xpByDifficulty[difficulty] ?? 50;
  const timeBonus = Math.round(estMinutes / 10) * 5; // small nudge for longer quests
  return base + timeBonus;
}
