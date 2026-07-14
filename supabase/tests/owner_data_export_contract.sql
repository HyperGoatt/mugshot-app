begin;

do $$
declare actor uuid; stranger uuid; payload jsonb;
begin
  select id into actor from public.users order by created_at limit 1;
  select id into stranger from public.users where id <> actor order by created_at limit 1;
  if actor is null or stranger is null then raise exception 'owner export contract requires two users'; end if;

  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', actor::text, true);
  set local role authenticated;
  payload := public.build_owner_data_export();

  if (payload ->> 'schema_version')::integer <> 1 then raise exception 'export schema version missing'; end if;
  if payload #>> '{profile,id}' <> actor::text then raise exception 'export returned the wrong profile'; end if;
  if exists(select 1 from jsonb_array_elements(payload -> 'journal_entries') row where row ->> 'user_id' <> actor::text) then
    raise exception 'another user journal entry leaked';
  end if;
  if exists(select 1 from jsonb_array_elements(payload -> 'private_notes') row where row ->> 'user_id' <> actor::text) then
    raise exception 'another user private note leaked';
  end if;
  if exists(select 1 from jsonb_array_elements(payload -> 'taste_signals') row where row ->> 'user_id' <> actor::text) then
    raise exception 'another user TasteSignal leaked';
  end if;
  if exists(select 1 from jsonb_array_elements(payload -> 'journal_entries') row where row ? 'private_note') then
    raise exception 'private notes were merged into shareable visit rows';
  end if;
end $$;

rollback;

select 'owner_data_export_contract_passed' as result;
