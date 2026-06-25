-- Applied as migration 'restore_quest_and_rerolls'.

-- Restore a skipped quest back to active (no XP involved).
create function public.restore_quest(p_quest_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update quests set status = 'active'
    where id = p_quest_id and user_id = (select auth.uid()) and status = 'skipped';
  if not found then
    raise exception 'skipped quest not found';
  end if;
end $$;

revoke execute on function public.restore_quest(uuid) from anon, public;

-- Daily reroll budget, tracked on the generation run (3 per user per day,
-- consumed atomically by the generate-quests edge function).
alter table public.generation_runs
  add column refresh_count integer not null default 0;
