-- Applied as migration 'signup_profile_prefs'.
-- Populate the new profile from optional signup metadata
-- (interests, age_range, location are collected in the app's signup flow).
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  meta_interests jsonb;
  meta_age text;
begin
  meta_interests := case
    when jsonb_typeof(new.raw_user_meta_data->'interests') = 'array'
      then new.raw_user_meta_data->'interests'
    else '[]'::jsonb
  end;

  meta_age := new.raw_user_meta_data->>'age_range';
  if meta_age is not null and meta_age not in ('13-17','18-24','25-34','35-49','50+') then
    meta_age := null;
  end if;

  insert into public.profiles (id, display_name, interests, age_range, location)
  values (
    new.id,
    new.raw_user_meta_data->>'display_name',
    meta_interests,
    meta_age,
    nullif(trim(new.raw_user_meta_data->>'location'), '')
  );
  return new;
end $$;
