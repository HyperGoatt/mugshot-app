-- Preserve explicit owner deletion across old clients that do not encode the
-- new optional workspace fields. No existing row or recipe version is rewritten.
begin;
set local lock_timeout = '5s';

create or replace function private.home_workspace_apply_deletions_v1(p_prior jsonb, p_incoming jsonb)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare
  result jsonb := p_incoming; removed jsonb := '{}'::jsonb;
  kind text; section text; values_json jsonb; item jsonb; record_json jsonb; source_document jsonb;
  records jsonb := '[]'::jsonb; make_ids jsonb; draft_ids jsonb; pub_ids jsonb;
  retained_publications jsonb := '[]'::jsonb; removes_record boolean;
  prior_photo_names jsonb := '[]'::jsonb; retired_photos jsonb; is_prior boolean := true;
  uuid_pattern constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
  photo_pattern constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\.jpg$';
begin
  if coalesce(jsonb_typeof(p_prior->'deletions'),'null') = 'null'
    and coalesce(jsonb_typeof(p_incoming->'deletions'),'null') = 'null' then return result; end if;
  foreach item in array array[p_prior, p_incoming] loop
    if coalesce(jsonb_typeof(item->'deletions'),'null') not in ('null','object') then
      raise exception 'Invalid Home deletion document' using errcode = '22023';
    end if;
  end loop;
  foreach kind in array array['attempts','attemptDrafts','recipeDrafts','publications','publicationDrafts','photoNames'] loop
    foreach item in array array[p_prior, p_incoming] loop
      if coalesce(jsonb_typeof(item#>array['deletions',kind]),'null') not in ('null','array') then
        raise exception 'Invalid Home deletion list' using errcode = '22023';
      end if;
      for record_json in select value from jsonb_array_elements(
        case when jsonb_typeof(item#>array['deletions',kind])='array'
          then item#>array['deletions',kind] else '[]'::jsonb end)
      loop
        if jsonb_typeof(record_json) <> 'string' or (record_json#>>'{}') !~
          (case when kind='photoNames' then photo_pattern else uuid_pattern end) then
          raise exception 'Invalid Home deletion identifier' using errcode = '22023';
        end if;
      end loop;
    end loop;
    select coalesce(jsonb_agg(value order by value),'[]'::jsonb) into values_json from (
      select distinct case when kind='photoNames' then value else to_jsonb(lower(value#>>'{}')) end as value from jsonb_array_elements(
        (case when jsonb_typeof(p_prior#>array['deletions',kind])='array' then p_prior#>array['deletions',kind] else '[]'::jsonb end)
        || (case when jsonb_typeof(p_incoming#>array['deletions',kind])='array' then p_incoming#>array['deletions',kind] else '[]'::jsonb end))
    ) entries;
    removed := removed || jsonb_build_object(kind,values_json);
  end loop;

  -- Retain each record's collection so discarding an obsolete draft never
  -- becomes deletion of a concurrently saved sip with the same make ID.
  foreach source_document in array array[p_prior, p_incoming] loop
    foreach section in array array['attempts','attemptDrafts','attemptConflicts'] loop
      if jsonb_typeof(source_document->section)='array' then
        for record_json in select value from jsonb_array_elements(source_document->section) loop
          records := records || jsonb_build_array(jsonb_build_object('section',section,'record',record_json,'isPrior',is_prior));
        end loop;
      end if;
    end loop;
    foreach section in array array['sessions','preparationConflicts'] loop
      if jsonb_typeof(source_document->section)='array' then
        for record_json in select value from jsonb_array_elements(source_document->section) loop
          if jsonb_typeof(record_json->'attempt')='object' then
            records := records || jsonb_build_array(jsonb_build_object('section',section,'record',record_json->'attempt','isPrior',is_prior));
          end if;
        end loop;
      end if;
    end loop;
    is_prior := false;
  end loop;
  pub_ids := removed->'publications';
  for item in select value from jsonb_array_elements(records) loop
    record_json := item->'record';
    if (pub_ids ? lower(record_json->>'id') or pub_ids ? lower(record_json->>'publicationDraftID'))
      and (record_json->>'id') ~ uuid_pattern then
      removed := jsonb_set(removed,'{attempts}',(removed->'attempts') || jsonb_build_array(lower(record_json->>'id')));
    end if;
  end loop;
  -- Edits have their own draft IDs. A removed saved source cannot return as
  -- an independent edit, conflict, or preparation session on an older client.
  for item in select value from jsonb_array_elements(records) loop
    record_json := item->'record';
    if item->>'section' <> 'attempts'
      and coalesce((removed->'attempts') ? lower(record_json->>'editingAttemptID'),false)
      and (record_json->>'id') ~ uuid_pattern then
      removed := jsonb_set(removed,'{attemptDrafts}',(removed->'attemptDrafts') || jsonb_build_array(lower(record_json->>'id')));
    end if;
  end loop;
  make_ids := (removed->'attempts') || (removed->'attemptDrafts');
  draft_ids := removed->'recipeDrafts';
  foreach section in array array['attempts','attemptDrafts','attemptConflicts','sessions','preparationConflicts','recipeDrafts'] loop
    if jsonb_typeof(result->section) is distinct from 'array' then continue; end if;
    select coalesce(jsonb_agg(value order by ordinal),'[]'::jsonb) into values_json
    from jsonb_array_elements(result->section) with ordinality entries(value,ordinal)
    where case
      when section='recipeDrafts' then not coalesce(draft_ids ? lower(value->>'id'),false)
      when section='attempts' then
        not coalesce((removed->'attempts') ? lower(value->>'id'),false) and not coalesce(pub_ids ? lower(value->>'publicationDraftID'),false)
      when section in ('sessions','preparationConflicts') then
        not coalesce(make_ids ? lower(value#>>'{attempt,id}'),false) and not coalesce(pub_ids ? lower(value#>>'{attempt,publicationDraftID}'),false)
      else not coalesce(make_ids ? lower(value->>'id'),false) and not coalesce(pub_ids ? lower(value->>'publicationDraftID'),false) end;
    result := jsonb_set(result,array[section],values_json);
  end loop;
  if jsonb_typeof(result->'attempts')='array' then
    for record_json in select value from jsonb_array_elements(result->'attempts') loop
      if (record_json->>'id') ~ uuid_pattern then
        retained_publications := retained_publications || jsonb_build_array(lower(record_json->>'id'));
      end if;
      if (record_json->>'publicationDraftID') ~ uuid_pattern then
        retained_publications := retained_publications || jsonb_build_array(lower(record_json->>'publicationDraftID'));
      end if;
    end loop;
  end if;
  -- Queue cleanup only from records actually removed. Shared filenames remain
  -- candidates; clients must retain every name still referenced after the ack.
  for item in select value from jsonb_array_elements(records) loop
    record_json := item->'record';
    if (item->>'isPrior')::boolean and jsonb_typeof(record_json->'photoNames')='array' then
      prior_photo_names := prior_photo_names || (record_json->'photoNames');
    end if;
    removes_record := case when item->>'section'='attempts'
      then coalesce((removed->'attempts') ? lower(record_json->>'id'),false)
      else coalesce(make_ids ? lower(record_json->>'id'),false) end;
    if removes_record then
      if (record_json->>'publicationDraftID') ~ uuid_pattern
        and not coalesce(retained_publications ? lower(record_json->>'publicationDraftID'),false) then
        removed := jsonb_set(removed,'{publicationDrafts}',(removed->'publicationDrafts') || jsonb_build_array(lower(record_json->>'publicationDraftID')));
      end if;
      if jsonb_typeof(record_json->'photoNames')='array' then
        for values_json in select value from jsonb_array_elements(record_json->'photoNames') loop
          if jsonb_typeof(values_json)='string' and (values_json#>>'{}') ~ photo_pattern then
            removed := jsonb_set(removed,'{photoNames}',(removed->'photoNames') || jsonb_build_array(values_json));
          end if;
        end loop;
      end if;
    end if;
  end loop;
  -- Once an acknowledged document has retired the last reference, another
  -- client cannot attach that object while Storage cleanup is in flight. Names
  -- already shared in the prior document remain valid. Filtered deleted copies
  -- above do not count as new references and can still be retried by old clients.
  select coalesce(jsonb_agg(value),'[]'::jsonb) into retired_photos
  from jsonb_array_elements(case when jsonb_typeof(p_prior#>'{deletions,photoNames}')='array'
    then p_prior#>'{deletions,photoNames}' else '[]'::jsonb end)
  where not coalesce(prior_photo_names ? (value#>>'{}'),false);
  if jsonb_array_length(retired_photos)>0 then
    foreach section in array array['attempts','attemptDrafts','attemptConflicts','sessions','preparationConflicts'] loop
      if jsonb_typeof(result->section) is distinct from 'array' then continue; end if;
      for item in select value from jsonb_array_elements(result->section) loop
        record_json := case when section in ('sessions','preparationConflicts') then item->'attempt' else item end;
        if jsonb_typeof(record_json->'photoNames') is distinct from 'array' then continue; end if;
        if exists(select 1 from jsonb_array_elements(record_json->'photoNames') photo
          where coalesce(retired_photos ? (photo#>>'{}'),false)) then
          raise exception 'A retired private photo needs a new copy before it can be attached' using errcode='22023';
        end if;
      end loop;
    end loop;
  end if;
  foreach kind in array array['attempts','attemptDrafts','recipeDrafts','publications','publicationDrafts','photoNames'] loop
    select coalesce(jsonb_agg(value order by value),'[]'::jsonb) into values_json from (
      select distinct value from jsonb_array_elements(removed->kind)
    ) entries;
    removed := jsonb_set(removed,array[kind],values_json);
  end loop;
  result := jsonb_set(result,'{deletions}',removed);
  if octet_length(result::text)>8000000 then raise exception 'Invalid Home deletion document size' using errcode='22023'; end if;
  return result;
end;
$$;
revoke all on function private.home_workspace_apply_deletions_v1(jsonb,jsonb) from public,anon,authenticated;

create or replace function private.home_workspace_preserve_deletions_v1()
returns trigger language plpgsql security definer set search_path = '' as $$
declare prior jsonb := case when tg_op='UPDATE' then old.document else '{}'::jsonb end;
begin
  new.document := private.home_workspace_apply_deletions_v1(prior,new.document);
  -- Ordinary workspace cleanup must not hide a still-existing posted sip or
  -- bypass the existing remote-aware post deletion/recovery contract.
  if exists (select 1 from public.visits visit where visit.user_id=new.user_id and (
    (new.document#>'{deletions,publications}') ? visit.id::text or
    (new.document#>'{deletions,publicationDrafts}') ? visit.id::text or
    (new.document#>'{deletions,attempts}') ? visit.id::text or
    ((new.document#>'{deletions,attemptDrafts}') ? visit.id::text and not exists (
      select 1 from jsonb_array_elements(coalesce(new.document->'attempts','[]'::jsonb)) entry
      where lower(entry->>'id')=visit.id::text or lower(entry->>'publicationDraftID')=visit.id::text
    ))
  )) then raise exception 'Delete the posted sip through its post controls first' using errcode='22023'; end if;
  return new;
end;
$$;
revoke all on function private.home_workspace_preserve_deletions_v1() from public,anon,authenticated;
create trigger home_workspace_preserve_deletions
before insert or update of document on public.home_recipe_workspaces
for each row execute function private.home_workspace_preserve_deletions_v1();
commit;
