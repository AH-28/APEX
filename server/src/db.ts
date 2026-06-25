import Database from 'better-sqlite3';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { config } from './config.js';
import { TEMPLATES } from './seed/templates.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

export type DB = Database.Database;

export function openDb(path = config.dbPath): DB {
  const db = new Database(path);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  const schema = readFileSync(join(__dirname, '..', 'db', 'schema.sql'), 'utf8');
  db.exec(schema);
  seedTemplates(db);
  return db;
}

// Upsert seed templates so edits to templates.ts flow into existing DBs.
function seedTemplates(db: DB) {
  const upsert = db.prepare(`
    INSERT INTO quest_templates
      (id, category, pattern, title_hint, variables, difficulty, est_minutes, requires_photo, indoor_ok, min_age_range, active)
    VALUES (@id, @category, @pattern, @titleHint, @variables, @difficulty, @estMinutes, @requiresPhoto, @indoorOk, @minAgeRange, 1)
    ON CONFLICT(id) DO UPDATE SET
      category = excluded.category, pattern = excluded.pattern, title_hint = excluded.title_hint,
      variables = excluded.variables, difficulty = excluded.difficulty, est_minutes = excluded.est_minutes,
      requires_photo = excluded.requires_photo, indoor_ok = excluded.indoor_ok, min_age_range = excluded.min_age_range
  `);
  const tx = db.transaction(() => {
    for (const t of TEMPLATES) {
      upsert.run({
        id: t.id,
        category: t.category,
        pattern: t.pattern,
        titleHint: t.titleHint,
        variables: JSON.stringify(t.variables),
        difficulty: t.difficulty,
        estMinutes: t.estMinutes,
        requiresPhoto: t.requiresPhoto ? 1 : 0,
        indoorOk: t.indoorOk ? 1 : 0,
        minAgeRange: t.minAgeRange ?? null,
      });
    }
  });
  tx();
}
