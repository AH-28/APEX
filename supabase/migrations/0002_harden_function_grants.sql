-- Applied as migration 'harden_function_grants' (security-advisor follow-up).

-- handle_new_user is only ever invoked by the auth trigger; nobody should
-- call it through the REST RPC surface.
revoke execute on function public.handle_new_user() from anon, authenticated, public;

-- Quest RPCs are for signed-in users only.
revoke execute on function public.complete_quest(uuid, text) from anon, public;
revoke execute on function public.skip_quest(uuid) from anon, public;
