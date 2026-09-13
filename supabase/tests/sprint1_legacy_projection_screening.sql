begin;
do $$
declare owner_id uuid:='00000000-0000-4000-8000-000000000101';
 viewer_id uuid:='00000000-0000-4000-8000-000000000102';
 test_visit uuid:=gen_random_uuid(); parent_id uuid:=gen_random_uuid(); reply_id uuid:=gen_random_uuid();
 projected jsonb; recipe_id uuid; version_id uuid;
begin
 insert into public.visits(id,user_id,drink_type,drink_subtype,caption,visibility,ratings,overall_score,context_type,location_name,upload_state)
 values(test_visit,owner_id,'Coffee','Synthetic','','everyone','{"overall":4}',4,'Home','QA','complete');
 insert into public.visit_v3_reflections(visit_id,user_id,sip_score,mugshot_score,context_criteria)
 values(test_visit,owner_id,4,4,jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'name','Synthetic criterion','score',4,'weight',1,'sortOrder',0,'extra','Owner-only extra')));
 perform set_config('request.jwt.claim.sub',viewer_id::text,true);
 if exists(select 1 from public.get_visit_v3_reflection_v1(test_visit)) then raise exception 'pending reflection exposed';end if;
 perform pg_temp.approve_shared_fixture('visit',test_visit);
 select to_jsonb(r) into projected from public.get_visit_v3_reflection_v1(test_visit) r;
 if projected is null or projected::text like '%Owner-only extra%' then raise exception 'admitted reflection projection incorrect';end if;
 insert into public.comments(id,user_id,visit_id,text) values(parent_id,owner_id,test_visit,'Synthetic pending comment');
 if exists(select 1 from public.list_visit_comments_v2(test_visit)) then raise exception 'pending comment exposed';end if;
 perform pg_temp.approve_shared_fixture('comment',parent_id);
 insert into public.comments(id,user_id,visit_id,text,parent_comment_id) values(reply_id,owner_id,test_visit,'Synthetic pending reply',parent_id);
 if (select replies_count from public.list_visit_comments_v2(test_visit) where id=parent_id) is distinct from 0 then raise exception 'pending reply counted';end if;
 perform pg_temp.approve_shared_fixture('comment',reply_id);
 if (select count(*) from public.list_visit_comments_v2(test_visit))<>2
 or (select replies_count from public.list_visit_comments_v2(test_visit) where id=parent_id) is distinct from 1 then raise exception 'approved comments unavailable';end if;
 update public.comments set text='Synthetic edited comment' where id=parent_id;
 if exists(select 1 from public.list_visit_comments_v2(test_visit) where id=parent_id) then raise exception 'edited comment retained approval';end if;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 insert into public.recipe_identities(user_id,name) values(owner_id,'Synthetic recipe') returning id into recipe_id;
 insert into public.recipe_versions(recipe_identity_id,version_number,brew_details,visibility,source_kind,redistribution_allowed,public_reuse_acknowledged_at)
 values(recipe_id,1,'{}','everyone','original',true,now()) returning id into version_id;
 update public.visits set recipe_version_id=version_id where id=test_visit;
 perform pg_temp.approve_shared_fixture('visit',test_visit);
 perform set_config('request.jwt.claim.sub',viewer_id::text,true);
 if exists(select 1 from public.get_recipe_identity_for_visit_v1(test_visit)) then raise exception 'pending recipe identity exposed';end if;
 perform pg_temp.approve_shared_fixture('recipe',version_id);
 if not exists(select 1 from public.get_recipe_identity_for_visit_v1(test_visit)) then raise exception 'approved recipe identity unavailable';end if;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 update public.recipe_versions set visibility='private' where id=version_id;
 perform set_config('request.jwt.claim.sub',viewer_id::text,true);
 if exists(select 1 from public.get_recipe_identity_for_visit_v1(test_visit)) then raise exception 'private recipe identity exposed';end if;
end;
$$;
rollback;
