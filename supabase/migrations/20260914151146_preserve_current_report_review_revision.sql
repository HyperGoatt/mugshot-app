-- Retained restrictions must still show the current content to human reviewers.
create or replace function private.enqueue_screening_v1(p_kind text,p_id uuid,p_owner uuid,p_payload jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare existing private.screening_jobs; retained private.withdrawn_moderation_decisions;
begin
 select * into existing from private.screening_jobs where subject_kind=p_kind and subject_id=p_id for update;
 if p_payload is null then
   if existing.state='rejected' or (existing.state='needs_review' and
     (coalesce(existing.reason,'') not in ('invalid_input','provider_configuration','invalid_response','provider_unavailable','screening_unavailable')
      or existing.appeal_requested_at is not null)) then
     insert into private.withdrawn_moderation_decisions values
      (p_kind,p_id,existing.owner_id,existing.state,existing.reason,existing.evidence,existing.appeal_requested_at)
     on conflict(subject_kind,subject_id) do update set state=excluded.state,reason=excluded.reason,
      evidence=excluded.evidence,appeal_requested_at=excluded.appeal_requested_at;
   end if;
   delete from private.screening_jobs where subject_kind=p_kind and subject_id=p_id;
   return;
 end if;
 if jsonb_typeof(p_payload) is distinct from 'object'
 or jsonb_typeof(p_payload->'text') is distinct from 'string'
 or jsonb_typeof(p_payload->'images') is distinct from 'array'
 or octet_length(p_payload::text)>65536 then
   raise exception 'invalid shared content' using errcode='22023';
 end if;
 if private.local_text_rule_v1(p_payload->>'text') is not null then
   raise exception 'shared_text_not_allowed' using errcode='22023';
 end if;
 select * into retained from private.withdrawn_moderation_decisions where subject_kind=p_kind and subject_id=p_id;
 if retained.subject_id is not null and existing.subject_id is null then
   insert into private.screening_jobs(subject_kind,subject_id,owner_id,payload,state,reason,evidence,appeal_requested_at)
   values(p_kind,p_id,p_owner,p_payload,retained.state,retained.reason,retained.evidence,retained.appeal_requested_at);
   delete from private.withdrawn_moderation_decisions where subject_kind=p_kind and subject_id=p_id;
   return;
 end if;
 -- Genuine decisions are not cleared by editing, changing audience or retiring
 -- a provider. Moderators retain the existing review/appeal controls.
 if existing.state='rejected' or (existing.state='needs_review' and
   (coalesce(existing.reason,'') not in ('invalid_input','provider_configuration','invalid_response','provider_unavailable','screening_unavailable')
    or existing.appeal_requested_at is not null)) then
   if existing.payload is distinct from p_payload then
     insert into private.moderation_transition_receipts
      (subject_kind,subject_id,revision,owner_id,previous_state,previous_reason,previous_evidence)
     values(existing.subject_kind,existing.subject_id,existing.revision,existing.owner_id,existing.state,existing.reason,existing.evidence)
     on conflict do nothing;
     update private.screening_jobs set payload=p_payload,revision=gen_random_uuid(),
       lease_token=null,lease_until=null,updated_at=now()
     where subject_kind=p_kind and subject_id=p_id;
   end if;
   return;
 end if;
 if existing.subject_id is not null then
   insert into private.moderation_transition_receipts
    (subject_kind,subject_id,revision,owner_id,previous_state,previous_reason,previous_evidence)
   values(existing.subject_kind,existing.subject_id,existing.revision,existing.owner_id,existing.state,existing.reason,existing.evidence)
   on conflict do nothing;
 end if;
 insert into private.screening_jobs(subject_kind,subject_id,owner_id,payload,state,reason,evidence)
 values(p_kind,p_id,p_owner,p_payload,'approved','local_text_filter',jsonb_build_object('method','local_text_v1','photos','report_driven'))
 on conflict(subject_kind,subject_id) do update set
 owner_id=excluded.owner_id,payload=excluded.payload,revision=gen_random_uuid(),state='approved',
 reason='local_text_filter',evidence=excluded.evidence,attempts=0,lease_token=null,lease_until=null,updated_at=now()
 where private.screening_jobs.payload is distinct from excluded.payload or private.screening_jobs.reason is distinct from 'local_text_filter';
end;
$$;
