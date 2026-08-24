\set ON_ERROR_STOP on

begin;

do $test$
declare
  configured_job cron.job%rowtype;
begin
  if (
    select count(*)
    from vault.secrets
    where name = 'mugshot_activity_delivery_service_role'
  ) <> 1 then
    raise exception 'the activity delivery worker Vault secret is missing or ambiguous';
  end if;

  if (
    select count(*)
    from vault.secrets
    where name = 'mugshot_activity_delivery_worker_url'
  ) <> 1 then
    raise exception 'the activity delivery worker URL is missing or ambiguous';
  end if;

  if (
    select count(*)
    from cron.job job
    where job.jobname = 'mugshot-activity-delivery-v3'
       or job.command like '%/functions/v1/deliver-activity%'
       or job.command like '%deliver_v2%'
       or job.command like '%deliver_v3%'
  ) <> 1 then
    raise exception 'activity delivery scheduler ownership is ambiguous';
  end if;

  select job.*
  into configured_job
  from cron.job job
  where job.jobname = 'mugshot-activity-delivery-v3';

  if not found
     or configured_job.active is not true
     or configured_job.schedule <> '* * * * *'
     or configured_job.command not like '%deliver_v3%'
     or configured_job.command not like '%protocolVersion%3%'
     or configured_job.command not like '%vault.decrypted_secrets%'
     or configured_job.command not like '%mugshot_activity_delivery_service_role%'
     or configured_job.command not like '%mugshot_activity_delivery_worker_url%'
     or configured_job.command not like '%''apikey''%'
     or configured_job.command like '%Bearer eyJ%'
     or configured_job.command like '%sb_secret_%'
     or configured_job.command like '%''apikey'', ''eyJ%' then
    raise exception 'the activity delivery worker schedule is unsafe or incomplete';
  end if;
end;
$test$;

rollback;

select 'activity_delivery_schedule_v3_passed' as result;
