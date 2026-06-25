-- APEX core schema — applied to Supabase project `apex` (tugxgfpdcpsfzfckoqtc)
-- as migration 'apex_core_schema'. Kept in the repo so the project can be
-- recreated from scratch. Template seed data lives in server/src/seed/templates.ts.

create type difficulty_t as enum ('Easy','Medium','Hard');
create type quest_status_t as enum ('active','completed','skipped','expired');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  xp integer not null default 0,
  level integer not null default 1,
  interests jsonb not null default '[]',
  difficulty difficulty_t not null default 'Easy',
  location text,
  age_range text,
  timezone text not null default 'UTC',
  created_at timestamptz not null default now()
);

create table public.quest_templates (
  id text primary key,
  category text not null,
  pattern text not null,
  title_hint text not null,
  variables jsonb not null,
  difficulty difficulty_t not null,
  est_minutes integer not null check (est_minutes between 5 and 60),
  requires_photo boolean not null default false,
  indoor_ok boolean not null default true,
  min_age_range text,
  active boolean not null default true
);

create table public.quests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  template_id text not null references public.quest_templates(id),
  quest_date date not null,
  title text not null,
  description text not null,
  category text not null,
  difficulty difficulty_t not null,
  xp_reward integer not null,
  est_minutes integer not null,
  requires_photo boolean not null default false,
  variables jsonb not null default '{}'::jsonb,
  status quest_status_t not null default 'active',
  completed_at timestamptz,
  photo_path text,
  created_at timestamptz not null default now()
);
create index idx_quests_user_date on public.quests(user_id, quest_date);
create index idx_quests_user_status on public.quests(user_id, status);

create table public.generation_runs (
  user_id uuid not null references public.profiles(id) on delete cascade,
  quest_date date not null,
  quest_count integer not null,
  source text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, quest_date)
);

-- Auto-create a profile row whenever a user signs up.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, new.raw_user_meta_data->>'display_name');
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Row Level Security
alter table public.profiles enable row level security;
alter table public.quest_templates enable row level security;
alter table public.quests enable row level security;
alter table public.generation_runs enable row level security;

create policy "read own profile" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy "update own profile" on public.profiles
  for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- XP and level can only change through the complete_quest RPC.
revoke update on public.profiles from authenticated;
grant update (display_name, interests, difficulty, location, age_range, timezone)
  on public.profiles to authenticated;

create policy "templates readable" on public.quest_templates
  for select to authenticated using (true);

create policy "read own quests" on public.quests
  for select to authenticated using ((select auth.uid()) = user_id);
-- No insert/update policies: quests are written by the edge function
-- (service role) and mutated only via the RPCs below.

-- Complete a quest: validates ownership + status, awards XP atomically.
create function public.complete_quest(p_quest_id uuid, p_photo_path text default null)
returns json language plpgsql security definer set search_path = public as $$
declare
  q quests%rowtype;
  new_xp int;
  new_level int;
begin
  select * into q from quests
    where id = p_quest_id and user_id = (select auth.uid())
    for update;
  if not found then
    raise exception 'quest not found';
  end if;
  if q.status = 'completed' then
    raise exception 'quest already completed';
  end if;

  update quests
    set status = 'completed', completed_at = now(), photo_path = p_photo_path
    where id = q.id;

  update profiles
    set xp = xp + q.xp_reward,
        level = floor((xp + q.xp_reward) / 500.0)::int + 1
    where id = q.user_id
    returning xp, level into new_xp, new_level;

  return json_build_object('xp_awarded', q.xp_reward, 'total_xp', new_xp, 'level', new_level);
end $$;

create function public.skip_quest(p_quest_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update quests set status = 'skipped'
    where id = p_quest_id and user_id = (select auth.uid()) and status = 'active';
  if not found then
    raise exception 'active quest not found';
  end if;
end $$;

-- Proof photo storage: private bucket, users only touch their own folder.
insert into storage.buckets (id, name, public) values ('proofs', 'proofs', false);

create policy "upload own proofs" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'proofs' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "read own proofs" on storage.objects
  for select to authenticated
  using (bucket_id = 'proofs' and (storage.foldername(name))[1] = (select auth.uid())::text);
