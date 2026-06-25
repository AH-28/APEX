// APEX quest generation — Supabase Edge Function.
// Deployed to project `apex` (tugxgfpdcpsfzfckoqtc) as `generate-quests`.
//
// POST {}                  → idempotent daily generation: the first call of a
//                            user's day selects 5-8 templates (more as the
//                            user levels up), fills their variables (Claude
//                            or fallback) and inserts the quests; later
//                            calls return the existing rows.
// POST {action: 'reroll'}  → replaces today's unfinished (active/skipped)
//                            quests with fresh ones. Max 3 rerolls per day,
//                            consumed atomically; completed quests are kept.

import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const QUEST_COOLDOWN_DAYS = 7;
const HISTORY_DAYS = 14;
const REROLLS_PER_DAY = 3;
const XP_BY_DIFFICULTY: Record<string, number> = { Easy: 50, Medium: 100, Hard: 200 };
const MODEL = Deno.env.get('QUEST_MODEL') ?? 'claude-opus-4-8';

interface TemplateRow {
  id: string;
  category: string;
  pattern: string;
  title_hint: string;
  variables: Record<string, { description: string; examples: string[] }>;
  difficulty: 'Easy' | 'Medium' | 'Hard';
  est_minutes: number;
  requires_photo: boolean;
  indoor_ok: boolean;
  min_age_range: string | null;
}

interface Filled {
  templateId: string;
  title: string;
  variables: Record<string, string>;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // Identify the caller from their JWT (gateway already verified it).
  const jwt = req.headers.get('Authorization')?.replace('Bearer ', '') ?? '';
  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userData.user) return json({ error: 'unauthorized' }, 401);
  const userId = userData.user.id;

  const body = await req.json().catch(() => ({}));
  const action = body?.action === 'reroll' ? 'reroll' : 'today';

  const { data: profile } = await admin.from('profiles').select('*').eq('id', userId).single();
  if (!profile) return json({ error: 'profile not found' }, 404);

  const date = localDate(profile.timezone ?? 'UTC');

  const { data: existing } = await admin
    .from('quests').select('*').eq('user_id', userId).eq('quest_date', date)
    .order('created_at');
  const { data: run } = await admin
    .from('generation_runs').select('*').eq('user_id', userId).eq('quest_date', date)
    .maybeSingle();
  const rerollsLeft = Math.max(0, REROLLS_PER_DAY - (run?.refresh_count ?? 0));

  // ── Plain daily fetch ─────────────────────────────────────────
  if (action === 'today' && existing && existing.length > 0) {
    return json({ quests: existing, generated: false, rerolls_left: rerollsLeft });
  }

  // ── Reroll validation ─────────────────────────────────────────
  let replaceable: Record<string, unknown>[] = [];
  if (action === 'reroll') {
    if (!run || !existing || existing.length === 0) {
      return json({ error: 'nothing to reroll yet — fetch your daily quests first' }, 400);
    }
    replaceable = existing.filter((q) => q.status === 'active' || q.status === 'skipped');
    if (replaceable.length === 0) {
      return json({ error: 'no unfinished quests to reroll', rerolls_left: rerollsLeft }, 400);
    }
    // Consume one reroll atomically; fails when the budget is spent.
    const { data: consumed } = await admin
      .from('generation_runs')
      .update({ refresh_count: (run.refresh_count ?? 0) + 1 })
      .eq('user_id', userId).eq('quest_date', date)
      .lt('refresh_count', REROLLS_PER_DAY)
      .select('refresh_count');
    if (!consumed || consumed.length === 0) {
      return json({ error: 'no rerolls left today', rerolls_left: 0 }, 429);
    }
  }

  // ── History for repetition avoidance (includes today's rows) ──
  const historyCutoff = shiftDate(date, -HISTORY_DAYS);
  const cooldownCutoff = shiftDate(date, -QUEST_COOLDOWN_DAYS);
  const { data: history } = await admin
    .from('quests')
    .select('template_id, title, variables, quest_date')
    .eq('user_id', userId)
    .gte('quest_date', historyCutoff);

  const recentTemplateIds = new Set(
    (history ?? []).filter((h) => h.quest_date >= cooldownCutoff).map((h) => h.template_id),
  );
  const recentlyUsed: Record<string, string[]> = {};
  for (const h of history ?? []) {
    const values = Object.values((h.variables ?? {}) as Record<string, string>);
    recentlyUsed[h.template_id] = [...(recentlyUsed[h.template_id] ?? []), h.title, ...values];
  }

  // ── Template selection ────────────────────────────────────────
  const { data: templates } = await admin.from('quest_templates').select('*').eq('active', true);
  if (!templates || templates.length === 0) return json({ error: 'no templates' }, 500);

  const interests: string[] = Array.isArray(profile.interests) ? profile.interests : [];
  const count = action === 'reroll'
    ? replaceable.length
    : profile.level >= 10 ? 8 : profile.level >= 4 ? 6 : 5;
  // Today's templates are a hard exclusion (rerolls must never repeat today);
  // the 7-day cooldown is soft and relaxes if the catalogue runs thin.
  const todayTemplateIds = new Set((existing ?? []).map((q) => q.template_id as string));
  const selected = selectTemplates(templates as TemplateRow[], {
    interests,
    difficulty: profile.difficulty,
    ageRange: profile.age_range,
    excludeSoft: recentTemplateIds,
    excludeHard: todayTemplateIds,
    count,
  });

  // ── Fill variables (AI with deterministic fallback) ───────────
  let filled: Filled[];
  let source = 'fallback';
  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (apiKey) {
    try {
      filled = await fillWithClaude(apiKey, profile, selected, recentlyUsed);
      source = 'ai';
    } catch (e) {
      console.error('AI fill failed, using fallback:', e);
      filled = fillWithFallback(selected, recentlyUsed);
    }
  } else {
    filled = fillWithFallback(selected, recentlyUsed);
  }

  // ── Render, validate, persist ─────────────────────────────────
  const byId = new Map(selected.map((t) => [t.id, t]));
  const rows = [];
  for (const f of filled) {
    const t = byId.get(f.templateId);
    if (!t) continue;
    const description = render(t.pattern, f.variables);
    if (description.includes('{')) continue; // unfilled slot — never ship broken text
    rows.push({
      user_id: userId,
      template_id: t.id,
      quest_date: date,
      title: f.title.trim().slice(0, 60),
      description,
      category: t.category,
      difficulty: t.difficulty,
      xp_reward: (XP_BY_DIFFICULTY[t.difficulty] ?? 50) + Math.round(t.est_minutes / 10) * 5,
      est_minutes: t.est_minutes,
      requires_photo: t.requires_photo,
      variables: f.variables,
    });
  }

  if (action === 'reroll') {
    // Replace the unfinished quests with the fresh batch.
    const ids = replaceable.map((q) => q.id as string);
    await admin.from('quests').delete().in('id', ids);
    const { data: inserted, error: insErr } = await admin.from('quests').insert(rows).select();
    if (insErr) return json({ error: insErr.message }, 500);
    const { data: all } = await admin
      .from('quests').select('*').eq('user_id', userId).eq('quest_date', date)
      .order('created_at');
    return json({
      quests: all ?? inserted,
      generated: true,
      source,
      rerolls_left: Math.max(0, rerollsLeft - 1),
    });
  }

  // generation_runs PK makes concurrent double-generation impossible.
  const { error: runErr } = await admin
    .from('generation_runs')
    .insert({ user_id: userId, quest_date: date, quest_count: rows.length, source });
  if (runErr) {
    // Another request won the race — return what it created.
    const { data: theirs } = await admin
      .from('quests').select('*').eq('user_id', userId).eq('quest_date', date).order('created_at');
    return json({ quests: theirs ?? [], generated: false, rerolls_left: rerollsLeft });
  }

  const { data: inserted, error: insErr } = await admin.from('quests').insert(rows).select();
  if (insErr) return json({ error: insErr.message }, 500);
  return json({ quests: inserted, generated: true, source, rerolls_left: REROLLS_PER_DAY });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

function localDate(timezone: string, now = new Date()): string {
  try {
    return new Intl.DateTimeFormat('en-CA', { timeZone: timezone }).format(now);
  } catch {
    return new Intl.DateTimeFormat('en-CA', { timeZone: 'UTC' }).format(now);
  }
}

function shiftDate(isoDate: string, days: number): string {
  const d = new Date(isoDate + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

function render(pattern: string, vars: Record<string, string>): string {
  return pattern.replace(/\{(\w+)\}/g, (m, name: string) => vars[name] ?? m);
}

interface SelOpts {
  interests: string[];
  difficulty: 'Easy' | 'Medium' | 'Hard';
  ageRange: string | null;
  excludeSoft: Set<string>; // recent-history cooldown — relaxed if needed
  excludeHard: Set<string>; // today's templates — never relaxed
  count: number;
}

// Weighted random with category diversity: interest categories x3,
// matching difficulty x2 / adjacent x1 / opposite x0.25, max one quest
// per category per day. The history cooldown relaxes in stages if the
// catalogue runs thin, but today's templates are never repeated.
function selectTemplates(all: TemplateRow[], opts: SelOpts): TemplateRow[] {
  const rank = { Easy: 0, Medium: 1, Hard: 2 } as const;
  const ageOk = (t: TemplateRow) => {
    if (!t.min_age_range) return true;
    if (!opts.ageRange) return false;
    const order = ['13-17', '18-24', '25-34', '35-49', '50+'];
    return order.indexOf(opts.ageRange) >= order.indexOf(t.min_age_range);
  };
  let pool = all.filter(
    (t) => !opts.excludeSoft.has(t.id) && !opts.excludeHard.has(t.id) && ageOk(t),
  );
  if (pool.length < opts.count) {
    pool = all.filter((t) => !opts.excludeHard.has(t.id) && ageOk(t));
  }

  const weight = (t: TemplateRow) => {
    const iw = opts.interests.includes(t.category) ? 3 : 1;
    const dd = Math.abs(rank[t.difficulty] - rank[opts.difficulty]);
    return iw * (dd === 0 ? 2 : dd === 1 ? 1 : 0.25);
  };

  const picked: TemplateRow[] = [];
  const usedCategories = new Set<string>();
  let candidates = [...pool];
  while (picked.length < opts.count && candidates.length > 0) {
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

const SYSTEM_PROMPT = `You are the quest writer for APEX, a real-life side quest app. Users receive a few small daily quests that nudge them to explore, create, connect, and capture memories (often with a photo).

You will be given quest TEMPLATES with variable slots, plus a short user profile. Your job is to fill each template's variables and write a quest title.

Rules — every value you produce MUST keep the quest:
- completable within 5-60 minutes
- completely free (never require buying anything)
- safe, legal, and respectful of others' privacy and property
- suitable for a broad audience (family-friendly, no alcohol, no dangerous stunts)
- doable by one ordinary person with no special equipment

Style:
- Titles: 2-4 words, punchy and game-like (e.g. "Reflection Hunter", "Six-Word Sage"). Match the template's title hint. Never reuse a title the user has seen recently.
- Variable values: short phrases that drop naturally into the template pattern. Be specific and fresh — avoid the obvious first idea and avoid anything listed in recently_used.
- Personalise gently using the profile (interests, location, age range) without being creepy or assuming abilities.

Return values for EVERY template you are given, using each template's exact templateId and exact variable names.`;

const OUTPUT_SCHEMA = {
  type: 'object',
  properties: {
    quests: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          templateId: { type: 'string' },
          title: { type: 'string' },
          variables: {
            type: 'array',
            items: {
              type: 'object',
              properties: { name: { type: 'string' }, value: { type: 'string' } },
              required: ['name', 'value'],
              additionalProperties: false,
            },
          },
        },
        required: ['templateId', 'title', 'variables'],
        additionalProperties: false,
      },
    },
  },
  required: ['quests'],
  additionalProperties: false,
};

async function fillWithClaude(
  apiKey: string,
  profile: Record<string, unknown>,
  templates: TemplateRow[],
  recentlyUsed: Record<string, string[]>,
): Promise<Filled[]> {
  const payload = {
    profile: {
      interests: profile.interests,
      preferred_difficulty: profile.difficulty,
      level: profile.level,
      location: profile.location ?? 'unknown',
      age_range: profile.age_range ?? 'unknown',
    },
    templates: templates.map((t) => ({
      templateId: t.id,
      category: t.category,
      pattern: t.pattern,
      title_hint: t.title_hint,
      variables: t.variables,
    })),
    recently_used: recentlyUsed,
  };

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 4096,
      system: [
        // Stable prefix first -> prompt-cache hit on every generation after the first.
        { type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } },
      ],
      messages: [{ role: 'user', content: JSON.stringify(payload) }],
      output_config: { format: { type: 'json_schema', schema: OUTPUT_SCHEMA } },
    }),
  });
  if (!res.ok) throw new Error(`Anthropic API ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const data = await res.json();
  const text = data.content?.find((b: { type: string }) => b.type === 'text')?.text;
  if (!text) throw new Error('no text block in AI response');
  const parsed = JSON.parse(text) as {
    quests: { templateId: string; title: string; variables: { name: string; value: string }[] }[];
  };

  const byId = new Map(templates.map((t) => [t.id, t]));
  const out: Filled[] = [];
  for (const q of parsed.quests) {
    const t = byId.get(q.templateId);
    if (!t) continue;
    const vars: Record<string, string> = {};
    for (const v of q.variables) {
      if (t.variables[v.name] && v.value.trim()) vars[v.name] = v.value.trim();
    }
    if (Object.keys(t.variables).some((name) => !vars[name])) continue;
    out.push({ templateId: q.templateId, title: q.title, variables: vars });
  }
  // Backfill anything the model skipped.
  const got = new Set(out.map((q) => q.templateId));
  const leftover = templates.filter((t) => !got.has(t.id));
  out.push(...fillWithFallback(leftover, recentlyUsed));
  return out;
}

const FALLBACK_TITLES: Record<string, string[]> = {
  Photography: ['Lens Quest', 'Shutter Hunt', 'Frame Finder'],
  Adventure: ['Path Unknown', 'Local Explorer', 'New Horizons'],
  Fitness: ['Body Boost', 'Motion Mission', 'Power Minutes'],
  Learning: ['Brain Spark', 'Curious Mind', 'Fact Finder'],
  Social: ['Human Connection', 'Bridge Builder', 'Warm Words'],
  Creativity: ['Maker Mode', 'Idea Forge', 'Wild Canvas'],
  Productivity: ['Order Restored', 'Task Slayer', 'Future Proof'],
  Food: ['Flavor Quest', 'Kitchen Lab', 'Taste Trek'],
  Mindfulness: ['Still Point', 'Quiet Quest', 'Present Tense'],
  Nature: ['Wild Watch', 'Green Seeker', 'Sky Story'],
  Kindness: ['Secret Hero', 'Ripple Maker', 'Good Deed'],
  Music: ['Sound Safari', 'Ear Voyage', 'Rhythm Quest'],
};

function fillWithFallback(
  templates: TemplateRow[],
  recentlyUsed: Record<string, string[]>,
): Filled[] {
  return templates.map((t) => {
    const avoid = new Set((recentlyUsed[t.id] ?? []).map((s) => s.toLowerCase()));
    const vars: Record<string, string> = {};
    for (const [name, spec] of Object.entries(t.variables)) {
      const fresh = spec.examples.filter((e) => !avoid.has(e.toLowerCase()));
      const pool = fresh.length > 0 ? fresh : spec.examples;
      vars[name] = pool[Math.floor(Math.random() * pool.length)];
    }
    const titles = FALLBACK_TITLES[t.category] ?? ['Side Quest'];
    return {
      templateId: t.id,
      title: titles[Math.floor(Math.random() * titles.length)],
      variables: vars,
    };
  });
}
