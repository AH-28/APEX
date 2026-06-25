-- Applied as migration 'undo_quest'.

-- Undo a completed quest: revert to active and claw back the XP.
create function public.undo_quest(p_quest_id uuid)
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
  if q.status <> 'completed' then
    raise exception 'quest is not completed';
  end if;

  update quests
    set status = 'active', completed_at = null, photo_path = null
    where id = q.id;

  update profiles
    set xp = greatest(xp - q.xp_reward, 0),
        level = floor(greatest(xp - q.xp_reward, 0) / 500.0)::int + 1
    where id = q.user_id
    returning xp, level into new_xp, new_level;

  return json_build_object('xp_removed', q.xp_reward, 'total_xp', new_xp, 'level', new_level);
end $$;

revoke execute on function public.undo_quest(uuid) from anon, public;

-- Users may delete their own proof photos (needed when undoing a quest).
create policy "delete own proofs" on storage.objects
  for delete to authenticated
  using (bucket_id = 'proofs' and (storage.foldername(name))[1] = (select auth.uid())::text);
