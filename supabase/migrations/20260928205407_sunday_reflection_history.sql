-- Record a successful reminder independently of device registrations, which
-- are removed on sign-out/reinstallation. Failed or cancelled attempts are not
-- shown as received notifications.
alter table private.reflection_reminder_occurrences
  add column delivered_at timestamptz;

update private.reflection_reminder_occurrences occurrence
set delivered_at = sent.first_sent_at
from (
  select occurrence_id, min(completed_at) as first_sent_at
  from private.reflection_reminder_deliveries
  where status = 'sent'
  group by occurrence_id
) sent
where occurrence.id = sent.occurrence_id;

create function private.record_reflection_reminder_delivery_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'sent' and old.status is distinct from 'sent' then
    update private.reflection_reminder_occurrences occurrence
    set delivered_at = coalesce(occurrence.delivered_at, new.completed_at, now())
    where occurrence.id = new.occurrence_id;
  end if;
  return new;
end;
$$;

create trigger record_reflection_reminder_delivery_v1
after update of status on private.reflection_reminder_deliveries
for each row execute function private.record_reflection_reminder_delivery_v1();

revoke all on function private.record_reflection_reminder_delivery_v1()
  from public, anon, authenticated;

-- The private occurrence is exposed only to its authenticated owner, after
-- at least one device delivery succeeded. No private visit copy is projected.
create function public.list_reflection_reminders_v1(
  p_limit integer default 30,
  p_occurrence_id uuid default null
)
returns table (
  occurrence_id uuid,
  reminder_kind text,
  scheduled_at timestamptz,
  delivered_at timestamptz,
  timezone_name text,
  target_visit_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    occurrence.id,
    occurrence.reminder_kind,
    occurrence.scheduled_at,
    occurrence.delivered_at,
    occurrence.timezone_name,
    occurrence.target_visit_id
  from private.reflection_reminder_occurrences occurrence
  where auth.uid() is not null
    and occurrence.user_id = auth.uid()
    and occurrence.delivered_at is not null
    and (p_occurrence_id is null or occurrence.id = p_occurrence_id)
  order by occurrence.scheduled_at desc, occurrence.id desc
  limit least(greatest(coalesce(p_limit, 30), 1), 50);
$$;

revoke all on function public.list_reflection_reminders_v1(integer,uuid)
  from public, anon, authenticated;
grant execute on function public.list_reflection_reminders_v1(integer,uuid)
  to authenticated;

comment on function public.list_reflection_reminders_v1(integer,uuid) is
  'Caller-bound history of successfully delivered reflection reminders; no cross-account or undelivered occurrence access.';
