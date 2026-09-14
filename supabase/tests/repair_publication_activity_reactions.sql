begin;
-- Isolated, rolled-back fixtures; exercise real hosted authorization and triggers.
delete from public.profile_visibility_preferences where user_id in ('00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000102');
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000101';
set local role authenticated;
select public.acknowledge_profile_publication_v1(false);
reset role;
insert into public.visits(id,user_id,cafe_id,drink_type,caption,visibility,ratings,overall_score,context_type,category_scores,upload_state,created_at)
values('20000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000000101','10000000-0000-4000-8000-000000000101','Latte','Synthetic repair sip','friends','{"Overall":4}',4,'Cafe','[]','complete','2020-01-01');
insert into public.visit_tags(visit_id,tagged_user_id,tagged_by) values('20000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000101');
select pg_temp.approve_shared_fixture('visit','20000000-0000-4000-8000-000000009999');
do $$ begin
 if not private.profile_visit_published_v1('20000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000000101')
 or not private.profile_visit_published_v1('20000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000000102') then raise exception 'new Friends missing from profiles';end if;
 if private.profile_visit_published_v1('20000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000101') then raise exception 'historical Friends silently published';end if;
 if private.is_public_visit_discoverable_v3('20000000-0000-4000-8000-000000009999') then raise exception 'Friends entered public discovery';end if;
end $$;
set local role authenticated;
select public.set_profile_tagged_post_hidden_v1('20000000-0000-4000-8000-000000009999',true);
reset role;
do $$ begin
 if private.profile_visit_published_v1('20000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000000101')
 or not private.profile_visit_published_v1('20000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000000102') then raise exception 'author hide changed another profile';end if;
end $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000103';
set local role authenticated;
do $$ begin
 begin
 perform public.set_profile_tagged_post_hidden_v1('20000000-0000-4000-8000-000000009999',true);
 raise exception 'unrelated user hid a post';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
update public.visits set visibility='private' where id='20000000-0000-4000-8000-000000009999';
do $$ begin
 if private.profile_visit_published_v1('20000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000000102') then raise exception 'Private remained public';end if;
end $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000102';
set local role authenticated;
do $$ declare reaction text; result record;begin
 foreach reaction in array array['like','love','laugh','yummy'] loop
 select * into result from public.set_visit_reaction_v2('20000000-0000-4000-8000-000000000101',auth.uid(),reaction);
 if result.viewer_reaction is distinct from reaction then raise exception 'reaction roundtrip failed: %',reaction;end if;
 end loop;
end $$;
reset role;
insert into private.moderation_operators(user_id,role,is_active) values('00000000-0000-4000-8000-000000000101','admin',true) on conflict(user_id) do update set is_active=true;
select private.notify_moderation_operators_v1('repair-test','Synthetic alert','Synthetic body');
select private.notify_moderation_operators_v1('repair-test','Synthetic alert','Synthetic body');
do $$ declare e public.activity_events; begin
 if (select count(*) from public.activity_events where recipient_id='00000000-0000-4000-8000-000000000101' and dedupe_key='moderation:repair-test')<>1 then raise exception 'duplicate alert';end if;
 select * into e from public.activity_events where recipient_id='00000000-0000-4000-8000-000000000101' and dedupe_key='moderation:repair-test';
 if not private.activity_event_is_visible(e,e.recipient_id) or private.activity_event_is_visible(e,'00000000-0000-4000-8000-000000000102') then raise exception 'operator alert authorization';end if;
 update private.moderation_operators set is_active=false where user_id=e.recipient_id;
 if private.activity_event_is_visible(e,e.recipient_id) then raise exception 'revoked operator can see alert';end if;
end $$;
rollback;
