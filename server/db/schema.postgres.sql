-- APEX schema (PostgreSQL — production).
-- Functionally identical to the SQLite dev schema; uses native types,
-- JSONB, and constraints suited to Postgres.

CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- gen_random_uuid()

CREATE TYPE difficulty_t AS ENUM ('Easy', 'Medium', 'Hard');
CREATE TYPE quest_status_t AS ENUM ('active', 'completed', 'skipped', 'expired');

CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         CITEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  display_name  TEXT,
  xp            INTEGER NOT NULL DEFAULT 0,
  level         INTEGER NOT NULL DEFAULT 1,
  interests     JSONB NOT NULL DEFAULT '[]',
  difficulty    difficulty_t NOT NULL DEFAULT 'Easy',
  location      TEXT,
  age_range     TEXT,
  timezone      TEXT NOT NULL DEFAULT 'UTC',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE quest_templates (
  id             TEXT PRIMARY KEY,
  category       TEXT NOT NULL,
  pattern        TEXT NOT NULL,
  title_hint     TEXT NOT NULL,
  variables      JSONB NOT NULL,
  difficulty     difficulty_t NOT NULL,
  est_minutes    INTEGER NOT NULL CHECK (est_minutes BETWEEN 5 AND 60),
  requires_photo BOOLEAN NOT NULL DEFAULT FALSE,
  indoor_ok      BOOLEAN NOT NULL DEFAULT TRUE,
  min_age_range  TEXT,
  active         BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE quests (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  template_id    TEXT NOT NULL REFERENCES quest_templates(id),
  quest_date     DATE NOT NULL,
  title          TEXT NOT NULL,
  description    TEXT NOT NULL,
  category       TEXT NOT NULL,
  difficulty     difficulty_t NOT NULL,
  xp_reward      INTEGER NOT NULL,
  est_minutes    INTEGER NOT NULL,
  requires_photo BOOLEAN NOT NULL DEFAULT FALSE,
  variables      JSONB NOT NULL DEFAULT '{}',
  status         quest_status_t NOT NULL DEFAULT 'active',
  completed_at   TIMESTAMPTZ,
  photo_path     TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_quests_user_date ON quests(user_id, quest_date);
CREATE INDEX idx_quests_user_status ON quests(user_id, status);

CREATE TABLE generation_runs (
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  quest_date  DATE NOT NULL,
  quest_count INTEGER NOT NULL,
  source      TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, quest_date)
);

-- For the daily batch job: which users still need quests for a given date.
CREATE INDEX idx_users_timezone ON users(timezone);
