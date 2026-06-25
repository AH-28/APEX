export const config = {
  port: Number(process.env.PORT ?? 3000),
  dbPath: process.env.DB_PATH ?? 'apex.db',
  jwtSecret: process.env.JWT_SECRET ?? 'dev-only-secret-change-me',
  // Quest generation
  questsPerDay: { min: 5, max: 8 },
  historyDays: 14,          // window used for repetition avoidance
  templateCooldownDays: 7,  // a template can't repeat for the same user within this window
  // AI
  anthropicApiKey: process.env.ANTHROPIC_API_KEY,
  model: process.env.QUEST_MODEL ?? 'claude-opus-4-8',
  // XP economy: base reward per difficulty, clamped server-side (never trusted from AI)
  xpByDifficulty: { Easy: 50, Medium: 100, Hard: 200 } as Record<string, number>,
  xpPerLevel: 500,
};
