-- Keep the wire kind recognized by installed clients. New clients route the
-- query parameter to moderation; older clients safely open Activity Center.
alter function private.activity_event_is_visible(public.activity_events,uuid) rename to activity_event_is_visible_before_moderation_alerts;
create function private.activity_event_is_visible(p_event public.activity_events,p_viewer uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select case when p_event.metadata->>'source'='moderation_alert' then
 p_event.recipient_id=p_viewer and p_event.suppressed_at is null
 and private.is_live_account_as(p_viewer)
 and exists(select 1 from private.moderation_operators where user_id=p_viewer and is_active)
 else private.activity_event_is_visible_before_moderation_alerts(p_event,p_viewer) end;
$$;
alter function private.activity_candidate_event_v1(public.activity_events,uuid) rename to activity_candidate_event_before_moderation_alerts;
create function private.activity_candidate_event_v1(p_event public.activity_events,p_viewer uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select case when p_event.metadata->>'source'='moderation_alert' then private.activity_event_is_visible(p_event,p_viewer)
 else private.activity_candidate_event_before_moderation_alerts(p_event,p_viewer) end;
$$;
revoke all on function private.activity_event_is_visible(public.activity_events,uuid),private.activity_candidate_event_v1(public.activity_events,uuid) from public,anon,authenticated;

-- System service alerts may have the same recipient and actor; ordinary social
-- events keep their original self-notification prohibition.
do $$ declare c record; begin
 for c in select conname from pg_constraint where conrelid='public.activity_events'::regclass and contype='c' and pg_get_constraintdef(oid) like '%recipient_id <> actor_user_id%' loop
 execute format('alter table public.activity_events drop constraint %I',c.conname);
 end loop;
end $$;
alter table public.activity_events add constraint activity_events_no_social_self_alert
 check(recipient_id<>actor_user_id or coalesce(metadata->>'source'='moderation_alert',false));

create function private.notify_moderation_operators_v1(p_key text,p_title text,p_body text)
returns void language sql security definer set search_path='' as $$
 insert into public.activity_events(recipient_id,actor_user_id,kind,dedupe_key,title,body,deep_link,metadata)
 select op.user_id,op.user_id,'reaction',left('moderation:'||p_key,240),left(p_title,120),left(p_body,280),'mugshot://activity?screen=moderation','{"source":"moderation_alert"}'::jsonb
 from private.moderation_operators op where op.is_active and private.is_live_account_as(op.user_id)
 on conflict(recipient_id,dedupe_key) do nothing;
$$;
create function private.screening_operator_alert_v1() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.state='needs_review' and (new.reason in ('provider_flag','spam_signal') or new.appeal_requested_at is not null) then
 perform private.notify_moderation_operators_v1(new.subject_kind||':'||new.subject_id||':'||new.revision,
 'Shared content needs review','A safety flag or appeal needs your decision. Open Shared Content Status.');
 elsif new.state='service_error' then
 perform private.notify_moderation_operators_v1('service:'||coalesce(new.reason,'unknown')||':'||current_date,
 'Sharing checks need attention','A technical issue delayed screening. Open Service Status; this is not a content flag.');
 end if;
 return null;
end; $$;
create trigger screening_operator_alert after insert or update of state,appeal_requested_at on private.screening_jobs for each row execute function private.screening_operator_alert_v1();
create function private.report_operator_alert_v1() returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform private.notify_moderation_operators_v1('report:'||new.id,'New Mugshot report','A report needs your review. Open Reports and appeals.');
 return null;
end; $$;
create trigger report_operator_alert after insert on public.reports for each row execute function private.report_operator_alert_v1();
revoke all on function private.notify_moderation_operators_v1(text,text,text),private.screening_operator_alert_v1(),private.report_operator_alert_v1() from public,anon,authenticated;
