\set ON_ERROR_STOP on

-- Run by the disposable all-SQL harness. Public rows are read only: the real
-- trigger runs on temporary workspaces against exact reserved .invalid visits.
begin;

do $$
begin
  if current_setting('mugshot.qa_contract',true) is distinct from 'isolated' then
    raise exception 'Home deletion controls require isolated QA mode';
  end if;
  if has_function_privilege('anon','private.home_workspace_apply_deletions_v1(jsonb,jsonb)','EXECUTE')
    or has_function_privilege('authenticated','private.home_workspace_apply_deletions_v1(jsonb,jsonb)','EXECUTE')
    or has_function_privilege('anon','private.home_workspace_preserve_deletions_v1()','EXECUTE')
    or has_function_privilege('authenticated','private.home_workspace_preserve_deletions_v1()','EXECUTE') then
    raise exception 'Private deletion helpers are directly callable';
  end if;
  if not exists (select 1 from pg_proc where oid='private.home_workspace_apply_deletions_v1(jsonb,jsonb)'::regprocedure
    and provolatile='i' and proconfig @> array['search_path=""'])
    or not exists (select 1 from pg_proc where oid='private.home_workspace_preserve_deletions_v1()'::regprocedure
      and prosecdef and proconfig @> array['search_path=""']) then
    raise exception 'Home deletion helpers have unsafe execution settings';
  end if;
  if not exists (select 1 from pg_trigger where tgrelid='public.home_recipe_workspaces'::regclass
    and tgname='home_workspace_preserve_deletions' and not tgisinternal and tgenabled='O')
    or not (select relrowsecurity from pg_class where oid='public.home_recipe_workspaces'::regclass)
    or has_table_privilege('authenticated','public.home_recipe_workspaces','INSERT')
    or has_table_privilege('authenticated','public.home_recipe_workspaces','UPDATE') then
    raise exception 'Workspace writes bypass the owner RPC or deletion trigger';
  end if;
end;
$$;

create temp table home_deletion_contract_context as
select owner.id owner_id, other.id other_id, visit.id live_visit_id,
  (select to_jsonb(workspace) from public.home_recipe_workspaces workspace where workspace.user_id=owner.id) workspace_before
from auth.users owner
join auth.users other on other.id='00000000-0000-4000-8000-000000000102'::uuid
join public.visits visit on visit.id='20000000-0000-4000-8000-000000000101'::uuid and visit.user_id=owner.id
where owner.id='00000000-0000-4000-8000-000000000101'::uuid
  and owner.email='alpha-fixture-1@example.invalid'
  and other.email='alpha-fixture-2@example.invalid';
grant select on home_deletion_contract_context to authenticated;

do $$ begin
  if (select count(*) from home_deletion_contract_context)<>1 then
    raise exception 'Exact reserved Home deletion fixtures are required';
  end if;
end; $$;

create temp table home_deletion_contract_workspaces(user_id uuid not null,document jsonb not null);
create trigger home_deletion_contract_before_write
before insert or update of document on home_deletion_contract_workspaces
for each row execute function private.home_workspace_preserve_deletions_v1();

do $$
declare
  source_id uuid := gen_random_uuid(); edit_id uuid := gen_random_uuid(); kept_id uuid := gen_random_uuid();
  recipe_draft_id uuid := gen_random_uuid(); publication_id uuid := gen_random_uuid();
  photo_name text := upper(gen_random_uuid()::text)||'-'||upper(gen_random_uuid()::text)||'.jpg';
  empty_document jsonb := '{"schemaVersion":1,"recipes":[],"attempts":[],"attemptDrafts":[],"sessions":[],"recipeDrafts":[],"attemptConflicts":[],"preparationConflicts":[]}'::jsonb;
  prior jsonb; incoming jsonb; result jsonb; stale jsonb; saved jsonb; editing jsonb; section text;
begin
  -- Optional publication links are absent on ordinary private records. They
  -- must survive an unrelated recipe-draft removal and retain array ordering.
  prior := empty_document || jsonb_build_object(
    'attempts',jsonb_build_array(jsonb_build_object('id',source_id)),
    'attemptDrafts',jsonb_build_array(jsonb_build_object('id',kept_id)),
    'sessions',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'attempt',jsonb_build_object('id',kept_id))),
    'attemptConflicts',jsonb_build_array(jsonb_build_object('id',source_id)),
    'preparationConflicts',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'attempt',jsonb_build_object('id',kept_id))),
    'recipeDrafts',jsonb_build_array(jsonb_build_object('id',recipe_draft_id)));
  result := private.home_workspace_apply_deletions_v1(prior,prior||jsonb_build_object('deletions',jsonb_build_object('recipeDrafts',jsonb_build_array(recipe_draft_id))));
  foreach section in array array['attempts','attemptDrafts','sessions','attemptConflicts','preparationConflicts'] loop
    if result->section is distinct from prior->section then raise exception 'Unrelated private % disappeared',section; end if;
  end loop;

  -- A stale draft deletion never removes a make saved on another device or
  -- queues the retained saved sip's publication draft for ordinary cleanup.
  saved := jsonb_build_object('id',source_id,'publicationDraftID',publication_id,'name','Saved sip','photoNames',jsonb_build_array(photo_name));
  prior := empty_document || jsonb_build_object('attempts',jsonb_build_array(saved),
    'attemptDrafts',jsonb_build_array(jsonb_build_object('id',source_id)));
  result := private.home_workspace_apply_deletions_v1(prior,prior||jsonb_build_object('deletions',jsonb_build_object('attemptDrafts',jsonb_build_array(upper(source_id::text)))));
  if result->'attempts' is distinct from jsonb_build_array(saved) or jsonb_array_length(result->'attemptDrafts')<>0
    or (result#>'{deletions,publicationDrafts}') ? publication_id::text then
    raise exception 'Draft deletion changed a saved sip or its publication';
  end if;

  -- Distinct edit drafts, including conflict/session copies, follow source
  -- deletion. Their own IDs are marked before old-client recovery can clone them.
  editing := jsonb_build_object('id',edit_id,'editingAttemptID',upper(source_id::text),'photoNames',jsonb_build_array(photo_name));
  prior := empty_document || jsonb_build_object('attempts',jsonb_build_array(saved),
    'attemptDrafts',jsonb_build_array(editing,jsonb_build_object('id',kept_id)),
    'attemptConflicts',jsonb_build_array(editing),
    'sessions',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'attempt',editing)),
    'preparationConflicts',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'attempt',editing)));
  result := private.home_workspace_apply_deletions_v1(prior,prior||jsonb_build_object('deletions',jsonb_build_object('attempts',jsonb_build_array(source_id))));
  if jsonb_array_length(result->'attempts')<>0 or result->'attemptDrafts' is distinct from jsonb_build_array(jsonb_build_object('id',kept_id))
    or jsonb_array_length(result->'sessions')<>0 or jsonb_array_length(result->'attemptConflicts')<>0
    or jsonb_array_length(result->'preparationConflicts')<>0
    or not ((result#>'{deletions,attemptDrafts}') ? edit_id::text)
    or not ((result#>'{deletions,photoNames}') ? photo_name) then
    raise exception 'Deleted source left an editable draft or lost its exact media cleanup marker';
  end if;
  stale := private.home_workspace_apply_deletions_v1(result,prior);
  if stale->'attempts' is distinct from result->'attempts' or stale->'attemptDrafts' is distinct from result->'attemptDrafts'
    or stale->'recipes' is distinct from prior->'recipes' then
    raise exception 'An old client restored deleted work or changed recipes';
  end if;

  -- Normalize UUID identity while keeping Storage object names case-sensitive.
  result := private.home_workspace_apply_deletions_v1(
    empty_document||jsonb_build_object('deletions',jsonb_build_object('attempts',jsonb_build_array(upper(source_id::text)))),
    empty_document||jsonb_build_object('deletions',jsonb_build_object('attempts',jsonb_build_array(source_id),'photoNames',jsonb_build_array(photo_name))));
  if result#>'{deletions,attempts}' is distinct from jsonb_build_array(source_id::text)
    or result#>'{deletions,photoNames}' is distinct from jsonb_build_array(photo_name) then
    raise exception 'UUID normalization changed filenames or duplicated identity';
  end if;
  begin
    perform private.home_workspace_apply_deletions_v1('{}',empty_document||jsonb_build_object('deletions',
      jsonb_build_object('photoNames',jsonb_build_array(repeat('a',36)||'-'||repeat('b',36)||'.jpg'))));
    raise exception 'Malformed UUID photo cleanup marker was accepted';
  exception when sqlstate '22023' then null; end;
  begin
    perform private.home_workspace_apply_deletions_v1('{}',empty_document||'{"deletions":{"attempts":{}}}'::jsonb);
    raise exception 'Malformed deletion list was accepted';
  exception when sqlstate '22023' then null; end;

  -- Retired objects cannot gain references while asynchronous Storage cleanup
  -- runs. Stale deleted records are filtered first, and pre-existing shared
  -- references continue to protect the object.
  prior := empty_document||jsonb_build_object('attempts',jsonb_build_array(jsonb_build_object('id',source_id,'photoNames',jsonb_build_array(photo_name))));
  result := private.home_workspace_apply_deletions_v1(prior,prior||jsonb_build_object('deletions',jsonb_build_object('attempts',jsonb_build_array(source_id))));
  foreach section in array array['attempts','attemptDrafts','attemptConflicts','sessions','preparationConflicts'] loop
    editing := jsonb_build_object('id',edit_id,'photoNames',jsonb_build_array(photo_name));
    incoming := empty_document||jsonb_build_object(section,jsonb_build_array(case when section in ('sessions','preparationConflicts')
      then jsonb_build_object('id',gen_random_uuid(),'attempt',editing) else editing end));
    begin
      perform private.home_workspace_apply_deletions_v1(result,incoming);
      raise exception 'A retired photo acquired a new % reference',section;
    exception when sqlstate '22023' then null; end;
  end loop;
  stale := private.home_workspace_apply_deletions_v1(result,prior);
  if jsonb_array_length(stale->'attempts')<>0 then raise exception 'A stale deleted photo reference returned'; end if;
  prior := empty_document||jsonb_build_object('attempts',jsonb_build_array(
    jsonb_build_object('id',source_id,'photoNames',jsonb_build_array(photo_name)),
    jsonb_build_object('id',kept_id,'photoNames',jsonb_build_array(photo_name))));
  result := private.home_workspace_apply_deletions_v1(prior,prior||jsonb_build_object('deletions',jsonb_build_object('attempts',jsonb_build_array(source_id))));
  stale := private.home_workspace_apply_deletions_v1(result,result||jsonb_build_object('attempts',
    (result->'attempts')||jsonb_build_array(jsonb_build_object('id',edit_id,'photoNames',jsonb_build_array(photo_name)))));
  if jsonb_array_length(stale->'attempts')<>2 then raise exception 'A still-shared photo became unusable'; end if;
end;
$$;

do $$
declare
  context home_deletion_contract_context; section text; kind text; document jsonb; record_json jsonb;
  local_id uuid := gen_random_uuid(); absent_id uuid := gen_random_uuid();
  empty_document jsonb := '{"schemaVersion":1,"recipes":[],"attempts":[],"attemptDrafts":[],"sessions":[],"recipeDrafts":[],"attemptConflicts":[],"preparationConflicts":[]}'::jsonb;
begin
  select * into strict context from home_deletion_contract_context;
  foreach kind in array array['publications','publicationDrafts','attempts','attemptDrafts'] loop
    begin
      insert into home_deletion_contract_workspaces values(context.owner_id,empty_document||jsonb_build_object('deletions',
        jsonb_build_object(kind,jsonb_build_array(upper(context.live_visit_id::text)))));
      raise exception 'Live post accepted a % deletion marker',kind;
    exception when sqlstate '22023' then null; end;
  end loop;
  foreach section in array array['attempts','attemptDrafts','attemptConflicts','sessions','preparationConflicts'] loop
    record_json := jsonb_build_object('id',local_id,'publicationDraftID',upper(context.live_visit_id::text));
    document := empty_document||jsonb_build_object(section,jsonb_build_array(case when section in ('sessions','preparationConflicts')
      then jsonb_build_object('id',gen_random_uuid(),'attempt',record_json) else record_json end),
      'deletions',jsonb_build_object(case when section='attempts' then 'attempts' else 'attemptDrafts' end,jsonb_build_array(local_id)));
    begin
      insert into home_deletion_contract_workspaces values(context.owner_id,document);
      raise exception 'Incoming-only % bypassed post recovery',section;
    exception when sqlstate '22023' then null; end;
  end loop;
  -- A saved canonical mirror remains intact while its obsolete draft goes.
  record_json := jsonb_build_object('id',context.live_visit_id,'publicationDraftID',context.live_visit_id);
  insert into home_deletion_contract_workspaces as workspace values(context.owner_id,empty_document||jsonb_build_object(
    'attempts',jsonb_build_array(record_json),'attemptDrafts',jsonb_build_array(jsonb_build_object('id',context.live_visit_id)),
    'deletions',jsonb_build_object('attemptDrafts',jsonb_build_array(context.live_visit_id)))) returning workspace.document into document;
  if document->'attempts' is distinct from jsonb_build_array(record_json) then raise exception 'Saved post mirror disappeared'; end if;
  insert into home_deletion_contract_workspaces values(context.owner_id,empty_document||jsonb_build_object(
    'attempts',jsonb_build_array(jsonb_build_object('id',absent_id)),
    'deletions',jsonb_build_object('attempts',jsonb_build_array(absent_id))));
  update home_deletion_contract_workspaces as workspace set document=empty_document||jsonb_build_object(
    'attempts',jsonb_build_array(jsonb_build_object('id',absent_id)))
    where (workspace.document#>'{deletions,attempts}') ? absent_id::text returning workspace.document into document;
  if document is null or jsonb_array_length(document->'attempts')<>0 then
    raise exception 'An old-client UPDATE restored a confirmed deletion';
  end if;
  insert into home_deletion_contract_workspaces values(context.owner_id,
    empty_document||jsonb_build_object('deletions',jsonb_build_object('publications',jsonb_build_array(absent_id))));
  -- Identifiers from another owner's workspace cannot delete that owner's post.
  insert into home_deletion_contract_workspaces values(context.other_id,
    empty_document||jsonb_build_object('deletions',jsonb_build_object('publications',jsonb_build_array(context.live_visit_id))));
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub',(select owner_id::text from home_deletion_contract_context),true);
select set_config('request.jwt.claims',jsonb_build_object('sub',(select owner_id from home_deletion_contract_context),'role','authenticated')::text,true);
do $$ begin
  begin
    perform public.get_home_workspace_v1((select other_id from home_deletion_contract_context));
    raise exception 'Cross-owner workspace read unexpectedly succeeded';
  exception when sqlstate '42501' then null; end;
  if exists(select 1 from public.home_recipe_workspaces where user_id<>(select owner_id from home_deletion_contract_context)) then
    raise exception 'RLS exposed another owner workspace';
  end if;
end; $$;
reset role;

do $$ begin
  if not exists(select 1 from public.visits visit join home_deletion_contract_context context
    on visit.id=context.live_visit_id and visit.user_id=context.owner_id)
    or (select to_jsonb(workspace) from public.home_recipe_workspaces workspace where workspace.user_id=(select owner_id from home_deletion_contract_context))
      is distinct from (select workspace_before from home_deletion_contract_context) then
    raise exception 'Read-only public fixtures were changed by the deletion contract';
  end if;
end; $$;

rollback;
select 'home_workspace_deletion_controls_passed' as result;
