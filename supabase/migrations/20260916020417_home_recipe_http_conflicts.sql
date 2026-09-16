-- Business conflicts must not use PostgreSQL's transaction-retry SQLSTATE.
-- PostgREST retries 40001; these conflicts require an explicit client decision.
do $$
declare definition text;
begin
  definition := pg_get_functiondef('public.save_home_workspace_v1(bigint,uuid,jsonb,uuid)'::regprocedure);
  if definition not like '%HOME_WORKSPACE_CONFLICT%' then
    raise exception 'Expected Home workspace contract is missing';
  end if;
  definition := replace(definition, 'errcode = ''40001''', 'errcode = ''PT409''');
  if definition like '%40001%' or definition not like '%PT409%' then
    raise exception 'Home conflict HTTP mapping could not be verified';
  end if;
  execute definition;
end;
$$;
