-- Resolve consumer copy only after the caller/delivery visibility gate. Keep
-- durable event rows, read receipts and historical delivery identities intact.
create function private.activity_display_copy_v1(p_event public.activity_events)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare label text; title text; body text; reaction text;
begin
 if p_event.metadata->>'source'='moderation_alert' then
  return jsonb_build_object('title',p_event.title,'body',p_event.body);
 end if;
 select coalesce(nullif(btrim(display_name),''),'@'||username,'Someone') into label
 from public.users where id=p_event.actor_user_id;
 label:=coalesce(label,'Someone');
 case p_event.kind
 when 'friend_post' then title:=label||' posted a Mugshot';body:='A fresh friend sip is waiting in Feed.';
 when 'like' then
  select reaction_kind into reaction from public.likes where visit_id=p_event.visit_id and user_id=p_event.actor_user_id;
  title:=label||case coalesce(reaction,'like') when 'love' then ' loved your Mugshot' when 'laugh' then ' laughed at your Mugshot' when 'yummy' then ' reacted Yummy to your Mugshot' else ' liked your Mugshot' end;
  body:='See who enjoyed your sip.';
 when 'comment' then title:=label||' commented on your Mugshot';body:='There is a new comment in the conversation.';
 when 'comment_mention' then title:=label||' mentioned you';body:='You were mentioned in a Mugshot conversation.';
 when 'tag' then title:=label||' tagged you in a Mugshot';body:='Open Activity to see your tag.';
 when 'reaction' then title:=label||' reacted to your Mugshot';body:='Open your sip to see the reaction.';
 when 'friend_request' then title:=label||' wants to connect';body:='You have a new friend request.';
 when 'friend_request_accepted' then title:=label||' accepted your request';body:='You are friends on Mugshot now.';
 when 'collaborative_list_invitation' then title:=label||' invited you to a cafe list';body:='Plan cafes together.';
 when 'shared_mugshot_invitation' then title:=label||' invited you to share a Mugshot';body:='Open Activity to review the invitation.';
 else title:=label||' updated a cafe list';body:='Open the list to see what changed.';
 end case;
 return jsonb_build_object('title',left(title,120),'body',left(body,280));
end$$;
revoke all on function private.activity_display_copy_v1(public.activity_events) from public,anon,authenticated;

-- Hide retired service alerts consistently from lists, badges and future push
-- claims, while preserving the immutable event and its delivery history.
alter function private.activity_event_is_visible(public.activity_events,uuid) rename to activity_event_visible_before_regression_repair;
create function private.activity_event_is_visible(p_event public.activity_events,p_viewer uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select coalesce(p_event.dedupe_key not like 'moderation:service:%',true)
 and private.activity_event_visible_before_regression_repair(p_event,p_viewer);
$$;
revoke all on function private.activity_event_is_visible(public.activity_events,uuid) from public,anon,authenticated;

do $$declare source text; begin
 source:=pg_get_functiondef('public.list_activity_events_v1(integer,timestamptz,uuid)'::regprocedure);
 if strpos(source,'visible.title,')=0 or strpos(source,'else visible.body')=0 then raise exception 'Activity projection drift';end if;
 source:=replace(source,'visible.title,','private.activity_display_copy_v1((select e from public.activity_events e where e.id=visible.id))->>''title'',');
 source:=replace(source,'else visible.body','else private.activity_display_copy_v1((select e from public.activity_events e where e.id=visible.id))->>''body''');
 execute source;
 source:=pg_get_functiondef('public.claim_activity_push_batch_v2(integer)'::regprocedure);
 if strpos(source,'event.title,')=0 then raise exception 'Push projection drift';end if;
 source:=replace(source,'event.title,','private.activity_display_copy_v1(event)->>''title'',');
 source:=replace(source,'event.body,','private.activity_display_copy_v1(event)->>''body'',');
 execute source;
end$$;

-- Final fenced push revalidation also supplies freshly authorized display copy.
alter function public.revalidate_activity_push_delivery_v3(uuid,uuid,bigint) rename to revalidate_activity_push_delivery_before_copy;
create function public.revalidate_activity_push_delivery_v3(p_delivery_id uuid,p_claim_token uuid,p_lease_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; copy jsonb;begin
 result:=public.revalidate_activity_push_delivery_before_copy(p_delivery_id,p_claim_token,p_lease_version);
 if (result->>'eligible')::boolean then
  select private.activity_display_copy_v1(e) into copy from private.activity_push_deliveries d join public.activity_events e on e.id=d.activity_event_id
   where d.id=p_delivery_id and d.claim_token=p_claim_token and d.lease_version=p_lease_version and d.status='processing';
  if copy is null then return jsonb_build_object('eligible',false);end if;
  result:=result||copy;
 end if;
 return result;
end$$;
revoke all on function public.revalidate_activity_push_delivery_v3(uuid,uuid,bigint) from public,anon,authenticated;
grant execute on function public.revalidate_activity_push_delivery_v3(uuid,uuid,bigint) to service_role;

create function public.list_visit_reaction_people_v1(p_visit_id uuid,p_reaction_kind text default null,p_cursor jsonb default null,p_limit integer default 25)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid(); result jsonb;begin
 if actor is null or not private.is_live_account_as(actor) or not private.can_view_visit_as(p_visit_id,actor) then
  raise exception 'post unavailable' using errcode='42501';end if;
 if p_reaction_kind is not null and p_reaction_kind not in ('like','love','laugh','yummy') then raise exception 'invalid reaction' using errcode='22023';end if;
 if p_cursor is not null and not (p_cursor ?& array['created_at','user_id']) then raise exception 'invalid cursor' using errcode='22023';end if;
 with visible as materialized (
  select l.user_id,l.reaction_kind,l.created_at,coalesce(nullif(u.display_name,''),u.username,'Mugshot user') display_name,coalesce(u.username,'') username,u.avatar_url
  from public.likes l join public.users u on u.id=l.user_id
  where l.visit_id=p_visit_id and private.can_view_user_as(l.user_id,actor)
 ), page as (
  select * from visible where (p_reaction_kind is null or reaction_kind=p_reaction_kind)
   and (p_cursor is null or (created_at,user_id)<((p_cursor->>'created_at')::timestamptz,(p_cursor->>'user_id')::uuid))
  order by created_at desc,user_id desc limit greatest(1,least(coalesce(p_limit,25),50))
 ) select jsonb_build_object(
  'people',coalesce((select jsonb_agg(to_jsonb(p) order by created_at desc,user_id desc) from page p),'[]'::jsonb),
  'counts',jsonb_build_object('like_count',(select count(*) from visible where reaction_kind='like'),'love_count',(select count(*) from visible where reaction_kind='love'),'laugh_count',(select count(*) from visible where reaction_kind='laugh'),'yummy_count',(select count(*) from visible where reaction_kind='yummy'),'total_count',(select count(*) from visible),'viewer_reaction',(select reaction_kind from visible where user_id=actor)),
  'next_cursor',(select jsonb_build_object('created_at',p.created_at,'user_id',p.user_id) from (select * from page order by created_at,user_id limit 1) p
    where exists(select 1 from visible v where (p_reaction_kind is null or v.reaction_kind=p_reaction_kind) and (v.created_at,v.user_id)<(p.created_at,p.user_id))
    order by p.created_at,p.user_id limit 1)
 ) into result;
 return result;
end$$;
revoke all on function public.list_visit_reaction_people_v1(uuid,text,jsonb,integer) from public,anon;
grant execute on function public.list_visit_reaction_people_v1(uuid,text,jsonb,integer) to authenticated;

create index if not exists likes_visit_people_page_idx on public.likes(visit_id,created_at desc,user_id desc);
