begin;

-- The service credential is installed in Supabase Vault as an operational
-- prerequisite. This migration adopts at most one pre-existing delivery job,
-- replaces it with the canonical one-minute definition, and refuses to touch
-- ambiguous or credential-bearing scheduler state.
do $migration$
declare
  job_name constant text := 'mugshot-activity-delivery-v3';
  job_schedule constant text := '* * * * *';
  secret_name constant text := 'mugshot_activity_delivery_service_role';
  worker_url_name constant text := 'mugshot_activity_delivery_worker_url';
  worker_command constant text := $command$
    select net.http_post(
      url := (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'mugshot_activity_delivery_worker_url'
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'mugshot_activity_delivery_service_role'
        )
      ),
      body := jsonb_build_object(
        'action', 'deliver_v3',
        'protocolVersion', 3,
        'limit', 25
      ),
      timeout_milliseconds := 50000
    ) as request_id;
  $command$;
  existing_job_id bigint;
  existing_job_count integer;
begin
  if to_regprocedure('cron.schedule(text,text,text)') is null
     or to_regprocedure('cron.unschedule(bigint)') is null then
    raise exception 'pg_cron is required for the activity delivery worker';
  end if;

  if to_regprocedure(
    'net.http_post(text,jsonb,jsonb,jsonb,integer)'
  ) is null then
    raise exception 'pg_net is required for the activity delivery worker';
  end if;

  if (
    select count(*)
    from vault.secrets
    where name = secret_name
  ) <> 1 then
    raise exception 'the activity delivery worker Vault secret is missing or ambiguous';
  end if;

  if (
    select count(*)
    from vault.secrets
    where name = worker_url_name
  ) <> 1 then
    raise exception 'the activity delivery worker URL is missing or ambiguous';
  end if;

  select count(*)::integer, min(job.jobid)
  into existing_job_count, existing_job_id
  from cron.job job
  where job.jobname = job_name
     or job.command like '%/functions/v1/deliver-activity%'
     or job.command like '%deliver_v2%'
     or job.command like '%deliver_v3%';

  if existing_job_count > 1 then
    raise exception 'multiple activity delivery jobs require manual reconciliation';
  end if;

  if exists (
    select 1
    from cron.job job
    where (job.jobname = job_name
        or job.command like '%/functions/v1/deliver-activity%'
        or job.command like '%deliver_v2%'
        or job.command like '%deliver_v3%')
      and (
        job.command like '%sb_secret_%'
        or job.command like '%Bearer eyJ%'
        or job.command like '%''apikey'', ''eyJ%'
        or (
          (
            job.command ilike '%''apikey''%'
            or job.command ilike '%''Authorization''%'
          )
          and job.command not like '%vault.decrypted_secrets%'
        )
      )
  ) then
    raise exception 'an activity delivery job contains an embedded credential';
  end if;

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(job_name, job_schedule, worker_command);

  if (
    select count(*)
    from cron.job job
    where job.jobname = job_name
      and job.schedule = job_schedule
      and job.command = worker_command
      and job.active
  ) <> 1 then
    raise exception 'the activity delivery worker schedule was not installed';
  end if;

  if exists (
    select 1
    from cron.job job
    where job.jobname <> job_name
      and (
        job.command like '%/functions/v1/deliver-activity%'
        or job.command like '%deliver_v2%'
        or job.command like '%deliver_v3%'
      )
  ) then
    raise exception 'a noncanonical activity delivery job remains installed';
  end if;
end;
$migration$;

commit;
