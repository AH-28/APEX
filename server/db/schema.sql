-- APEX schema (SQLite — development/demo).
-- The production Postgres equivalent lives in schema.postgres.sql.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id            TEXT PRIMARY KEY,            -- uuid
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  display_name  TEXT,
  xp            INTEGER NOT NULL DEFAULT 0,
  level         INTEGER NOT NULL DEFAULT 1,
  -- profile / personalisation
  interests     TEXT NOT NULL DEFAULT '[]',  -- JSON array of category names
  difficulty    TEXT NOT NULL DEFAULT 'Easy' CHECK (difficulty IN ('Easy','Medium','Hard')),
  location      TEXT,                        -- optional, free text e.g. "Cairo, EG"
  age_range     TEXT,                        -- optional: '13-17','18-24','25-34','35-49','50+'
  timezone      TEXT NOT NULL DEFAULT 'UTC',
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS quest_templates (
  id            TEXT PRIMARY KEY,            -- stable slug, e.g. 'photo-reflections'
  category      TEXT NOT NULL,
  pattern       TEXT NOT NULL,               -- "Find and photograph {count} {subject} in different places."
  title_hint    TEXT NOT NULL,               -- style guidance for AI-generated titles
  variables     TEXT NOT NULL,               -- JSON: { name: { description, examples[] } }
  difficulty    TEXT NOT NULL CHECK (difficulty IN ('Easy','Medium','Hard')),
  est_minutes   INTEGER NOT NULL,            -- 5..60
  requires_photo INTEGER NOT NULL DEFAULT 0, -- photo proof encouraged (optional for user)
  indoor_ok     INTEGER NOT NULL DEFAULT 1,
  min_age_range TEXT,                        -- NULL = everyone
  active        INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS quests (
  id            TEXT PRIMARY KEY,            -- uuid
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  template_id   TEXT NOT NULL REFERENCES quest_templates(id),
  quest_date    TEXT NOT NULL,               -- 'YYYY-MM-DD' in the user's timezone
  title         TEXT NOT NULL,
  description   TEXT NOT NULL,
  category      TEXT NOT NULL,
  difficulty    TEXT NOT NULL,
  xp_reward     INTEGER NOT NULL,
  est_minutes   INTEGER NOT NULL,
  requires_photo INTEGER NOT NULL DEFAULT 0,
  variables     TEXT NOT NULL DEFAULT '{}',  -- JSON: the AI-filled values (for repetition control)
  status        TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','skipped','expired')),
  completed_at  TEXT,
  photo_path    TEXT,                        -- optional proof photo
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_quests_user_date ON quests(user_id, quest_date);
CREATE INDEX IF NOT EXISTS idx_quests_user_status ON quests(user_id, status);

-- Generation bookkeeping: one row per user per day, makes the daily job idempotent.
CREATE TABLE IF NOT EXISTS generation_runs (
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  quest_date  TEXT NOT NULL,
  quest_count INTEGER NOT NULL,
  source      TEXT NOT NULL,                 -- 'ai' | 'fallback'
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, quest_date)
);
