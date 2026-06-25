// AI variable-filling service.
//
// One Claude call per user per day fills the variable slots for all of that
// user's selected templates at once (cheaper + more coherent than one call
// per quest). Structured outputs guarantee parseable JSON; the static system
// prompt carries a cache_control breakpoint so the per-request cost is mostly
// the small user-specific payload.
//
// If ANTHROPIC_API_KEY is not set (local dev) or the call fails, the
// deterministic fallback fills slots from each variable's example pool,
// avoiding recently used values — quests still generate, just less creative.

import Anthropic from '@anthropic-ai/sdk';
import { config } from '../config.js';
import type { QuestTemplate } from '../seed/templates.js';

export interface UserContext {
  interests: string[];
  difficulty: string;
  level: number;
  location?: string | null;
  ageRange?: string | null;
}

export interface FilledQuest {
  templateId: string;
  title: string;
  variables: Record<string, string>;
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

// Static JSON schema (variables as name/value pairs so one schema covers all templates).
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
              properties: {
                name: { type: 'string' },
                value: { type: 'string' },
              },
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
} as const;

export interface FillRequest {
  user: UserContext;
  templates: QuestTemplate[];
  recentlyUsed: Record<string, string[]>; // templateId -> recent variable values/titles to avoid
}

export interface FillResult {
  quests: FilledQuest[];
  source: 'ai' | 'fallback';
}

export async function fillTemplates(req: FillRequest): Promise<FillResult> {
  if (config.anthropicApiKey) {
    try {
      return { quests: await fillWithClaude(req), source: 'ai' };
    } catch (err) {
      console.error('AI fill failed, using fallback:', err);
    }
  }
  return { quests: fillWithFallback(req), source: 'fallback' };
}

async function fillWithClaude(req: FillRequest): Promise<FilledQuest[]> {
  const client = new Anthropic({ apiKey: config.anthropicApiKey });

  const payload = {
    profile: {
      interests: req.user.interests,
      preferred_difficulty: req.user.difficulty,
      level: req.user.level,
      location: req.user.location ?? 'unknown',
      age_range: req.user.ageRange ?? 'unknown',
    },
    templates: req.templates.map((t) => ({
      templateId: t.id,
      category: t.category,
      pattern: t.pattern,
      title_hint: t.titleHint,
      variables: Object.fromEntries(
        Object.entries(t.variables).map(([name, v]) => [name, { description: v.description, examples: v.examples }]),
      ),
    })),
    recently_used: req.recentlyUsed,
  };

  const response = await client.messages.create({
    model: config.model,
    max_tokens: 2048,
    system: [
      // Stable prefix first → prompt-cache hit on every generation after the first.
      { type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } },
    ],
    messages: [{ role: 'user', content: JSON.stringify(payload) }],
    output_config: { format: { type: 'json_schema', schema: OUTPUT_SCHEMA } },
  });

  const text = response.content.find((b) => b.type === 'text');
  if (!text || text.type !== 'text') throw new Error('No text block in AI response');
  const parsed = JSON.parse(text.text) as {
    quests: { templateId: string; title: string; variables: { name: string; value: string }[] }[];
  };

  // Validate: every requested template must come back with all of its variables.
  const byId = new Map(req.templates.map((t) => [t.id, t]));
  const quests: FilledQuest[] = [];
  for (const q of parsed.quests) {
    const template = byId.get(q.templateId);
    if (!template) continue;
    const variables: Record<string, string> = {};
    for (const v of q.variables) {
      if (template.variables[v.name] && v.value.trim()) variables[v.name] = v.value.trim();
    }
    const missing = Object.keys(template.variables).filter((name) => !variables[name]);
    if (missing.length > 0) continue; // incomplete — let the per-template fallback cover it
    quests.push({ templateId: q.templateId, title: q.title.trim().slice(0, 60), variables });
  }

  // Backfill any templates the model skipped or returned incomplete.
  const got = new Set(quests.map((q) => q.templateId));
  const leftover = req.templates.filter((t) => !got.has(t.id));
  if (leftover.length > 0) {
    quests.push(...fillWithFallback({ ...req, templates: leftover }));
  }
  return quests;
}

// Deterministic fallback: rotate through each variable's example pool,
// skipping values used recently for this user.
export function fillWithFallback(req: FillRequest): FilledQuest[] {
  return req.templates.map((t) => {
    const avoid = new Set((req.recentlyUsed[t.id] ?? []).map((s) => s.toLowerCase()));
    const variables: Record<string, string> = {};
    for (const [name, spec] of Object.entries(t.variables)) {
      const fresh = spec.examples.filter((e) => !avoid.has(e.toLowerCase()));
      const pool = fresh.length > 0 ? fresh : spec.examples;
      variables[name] = pool[Math.floor(Math.random() * pool.length)];
    }
    return { templateId: t.id, title: defaultTitle(t), variables };
  });
}

function defaultTitle(t: QuestTemplate): string {
  const names: Record<string, string[]> = {
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
  const pool = names[t.category] ?? ['Side Quest'];
  return pool[Math.floor(Math.random() * pool.length)];
}
