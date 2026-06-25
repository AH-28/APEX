# APEX — Real Life Side Quests

Every day you get 5–8 small, personalised real-world quests: explore, photograph,
create, connect. Complete them, earn XP, level up, and build a journal of memories.

- **App**: Flutter — iOS, Android, macOS, Windows, Linux, and Web from one codebase ([app/](app))
- **Backend**: **Supabase** (project `apex`, ID `tugxgfpdcpsfzfckoqtc`) — Postgres + Auth +
  Storage + an Edge Function for quest generation. Nothing to run locally.
- **Quest generation**: hybrid — a curated template catalogue + Claude filling the
  variables with structured output, with a deterministic fallback. Full design in
  [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Run the app

```bash
cd app
flutter run        # pick a device: macOS, Chrome, simulator…
```

That's it — the app is pre-wired to the Supabase project (URL + publishable key in
[app/lib/main.dart](app/lib/main.dart); safe to ship, row-level security guards the data).

## Where everything lives

| What | Where |
|---|---|
| Database, users, photos | [supabase.com/dashboard](https://supabase.com/dashboard) → project **apex** → Table Editor / Authentication / Storage |
| Quest generation logic | Edge Function `generate-quests` — source mirrored at [supabase/functions/generate-quests/index.ts](supabase/functions/generate-quests/index.ts) |
| Database schema | [supabase/migrations/](supabase/migrations) (already applied to the live project) |
| Quest templates | Seeded into the `quest_templates` table; authored in [server/src/seed/templates.ts](server/src/seed/templates.ts) |
| Legacy self-hosted backend | [server/](server) — the original Node/SQLite implementation, kept for local-only development (`cd server && npm start`) |

## Backend architecture (Supabase)

- **Auth**: Supabase email+password. A trigger creates a `profiles` row on signup.
- **Generation**: the app calls the `generate-quests` Edge Function; first call of a
  user's day selects templates and fills variables (Claude → fallback), later calls
  return the same rows. Idempotent via the `generation_runs` primary key.
- **Integrity**: XP/level can *only* change through the `complete_quest` RPC
  (`security definer`); clients can't write quests or XP directly (RLS + column grants).
- **Photos**: private `proofs` bucket; each user can only touch their own folder.

## Enabling AI personalisation

The function runs in template-fallback mode until you add the key:
Dashboard → Project Settings → **Edge Functions** → Secrets → add
`ANTHROPIC_API_KEY` (needs an Anthropic account with credits).

## Dev notes

- **Email confirmation** is ON by default and Supabase's built-in mailer only sends
  ~2 emails/hour. For development, turn it off: Dashboard → Authentication →
  Sign In / Providers → Email → disable "Confirm email". For production, configure
  custom SMTP instead.
- Recommended (from Supabase's security advisor): enable leaked-password protection
  under Authentication → Sign In / Providers.
- Test account that already exists: `tester@apexdev.local` / `apexdemo123`.
