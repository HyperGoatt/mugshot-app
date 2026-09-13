-- V3 builds its initial row through V2 before sealing the exact manifest.
-- A non-empty initial manifest must satisfy the count constraint at INSERT,
-- not only at V3's later UPDATE. Keep the constraint and authorization intact.
do $$
declare
  source text := pg_get_functiondef('public.prepare_account_deletion_v2(uuid,uuid)'::regprocedure);
  original text := E'    storage_manifest,\n    collaboration_manifest\n  ) values (\n    p_request_id,\n    p_subject_id,\n    storage_rows,';
  replacement text := E'    storage_manifest,\n    storage_manifest_object_count,\n    collaboration_manifest\n  ) values (\n    p_request_id,\n    p_subject_id,\n    storage_rows,\n    jsonb_array_length(storage_rows),';
begin
  if strpos(source, original) = 0 then
    raise exception 'Unexpected account preparation definition';
  end if;
  execute replace(source, original, replacement);
end;
$$;
