begin;
do $$
declare owner_id uuid:='00000000-0000-4000-8000-000000000101'; test_visit uuid:=gen_random_uuid(); payload text; projection jsonb;
begin
 insert into public.visits(id,user_id,drink_type,drink_subtype,caption,visibility,ratings,overall_score,context_type,location_name,upload_state,brew_method,brew_method_visible,equipment,equipment_visible)
 values(test_visit,owner_id,'Coffee','Synthetic','', 'everyone','{"overall":4}',4,'Home','QA','complete','VISIBLE METHOD',true,'PRIVATE EQUIPMENT',false);
 insert into public.visit_v3_reflections(visit_id,user_id,sip_score,mugshot_score,sip_raw_note,context_raw_note,raw_note_visibility,context_criteria)
 values(test_visit,owner_id,4,4,'PRIVATE RAW NOTE','PRIVATE CONTEXT','private',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'name','VISIBLE CRITERION','score',4,'weight',1,'sortOrder',0,'extra','PRIVATE EXTRA')));
 select j.payload->>'text' into payload from private.screening_jobs j where subject_kind='visit' and subject_id=test_visit;
 if payload not like '%VISIBLE METHOD%' or payload not like '%VISIBLE CRITERION%' or payload like '%PRIVATE%' then raise exception 'canonical field allowlist failed';end if;
 update public.visit_v3_reflections set sip_raw_note='SHARED RAW NOTE',context_raw_note=null,raw_note_visibility='everyone' where visit_v3_reflections.visit_id=test_visit;
 select j.payload->>'text' into payload from private.screening_jobs j where subject_kind='visit' and subject_id=test_visit;
 if payload not like '%SHARED RAW NOTE%' then raise exception 'reflection edit did not refresh';end if;
 if public.get_canonical_post_v1(test_visit) is not null then raise exception 'pending canonical post exposed';end if;
 perform pg_temp.approve_shared_fixture('visit',test_visit);
 projection:=public.get_canonical_post_v1(test_visit);
 if projection is null or projection->'journal_note'->>'sip_note' is distinct from 'SHARED RAW NOTE' or projection::text like '%PRIVATE EXTRA%' then raise exception 'canonical admitted projection mismatch';end if;
 update public.visits set visibility='private' where id=test_visit;
 if exists(select 1 from private.screening_jobs where subject_kind='visit' and subject_id=test_visit) then raise exception 'Private post was queued';end if;
end;
$$;
rollback;
