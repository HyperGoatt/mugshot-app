begin;

do $$
declare
  owner_id uuid;
  stranger_id uuid;
  prefs public.user_reflection_preferences;
begin
  select id into owner_id from public.users order by created_at limit 1;
  select id into stranger_id from public.users where id <> owner_id order by created_at limit 1;
  if owner_id is null or stranger_id is null then
    raise exception 'reflection preference contract requires two users';
  end if;

  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  set local role authenticated;

  select * into prefs from public.get_reflection_preferences();
  if prefs.user_id <> owner_id or not prefs.monthly_recaps or not prefs.yearly_recaps
     or prefs.on_this_sip_reminders or prefs.reflection_reminders then
    raise exception 'reflection preference defaults are not conservative';
  end if;

  select * into prefs from public.set_reflection_preferences(false, true, true, false);
  if prefs.user_id <> owner_id or prefs.monthly_recaps or not prefs.yearly_recaps
     or not prefs.on_this_sip_reminders or prefs.reflection_reminders then
    raise exception 'caller-bound preference update failed';
  end if;

  if exists(select 1 from public.user_reflection_preferences where user_id = stranger_id) then
    raise exception 'owner can read another user reflection preferences';
  end if;

  begin
    update public.user_reflection_preferences set reflection_reminders=true where user_id=owner_id;
    raise exception 'direct preference update unexpectedly succeeded';
  exception when insufficient_privilege then
    null;
  end;
end $$;

rollback;

select 'reflection_preferences_contract_passed' as result;
