begin;
do $$
declare
  owner_id uuid := '00000000-0000-4000-8000-000000000104';
  request_id uuid := gen_random_uuid();
  prepared jsonb;
  object_count integer;
  manifest jsonb;
begin
  insert into storage.objects(bucket_id,name,owner,owner_id)
  values ('profile-media',owner_id::text || '/deletion-count-qa.png',owner_id,owner_id::text);
  prepared := public.prepare_account_deletion_v2(owner_id,request_id);
  select storage_manifest_object_count,storage_manifest into object_count,manifest
  from private.account_deletion_jobs where id=(prepared->>'job_id')::uuid;
  if object_count < 1 or object_count <> jsonb_array_length(manifest) then
    raise exception 'Initial deletion job lost its non-empty Storage manifest count';
  end if;
end;
$$;
rollback;
