begin;

-- Recovery must not depend on a foreground client surviving the destructive
-- request. Keep the bearer encrypted in Supabase Vault and let pg_cron enqueue
-- a bounded worker request every five minutes. The credential is installed as
-- an operational secret before this migration; it is never stored in Git or in
-- the cron command itself.
do $migration$
declare
  job_name constant text := 'mugshot-account-deletion-v3';
  job_schedule constant text := '*/5 * * * *';
  secret_name constant text := 'mugshot_account_deletion_service_role';
  worker_command constant text := $command$
    select net.http_post(
      url := 'https://quskamnfwglctqewwfln.supabase.co/functions/v1/delete-account',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'mugshot_account_deletion_service_role'
        )
      ),
      body := jsonb_build_object(
        'action', 'drain_deletions_v3',
        'protocolVersion', 3
      ),
      timeout_milliseconds := 10000
    ) as request_id;
  $command$;
  existing_job_id bigint;
begin
  if to_regprocedure(
    'cron.schedule(text,text,text)'
  ) is null then
    raise exception 'pg_cron is required for the account deletion worker';
  end if;

  if to_regprocedure(
    'net.http_post(text,jsonb,jsonb,jsonb,integer)'
  ) is null then
    raise exception 'pg_net is required for the account deletion worker';
  end if;

  if (
    select count(*)
    from vault.secrets
    where name = secret_name
  ) <> 1 then
    raise exception 'the account deletion worker Vault secret is missing or ambiguous';
  end if;

  select jobid
  into existing_job_id
  from cron.job
  where jobname = job_name
  limit 1;

  if existing_job_id is null then
    perform cron.schedule(job_name, job_schedule, worker_command);
  else
    update cron.job
    set schedule = job_schedule,
        command = worker_command,
        active = true
    where jobid = existing_job_id;
  end if;

  if not exists (
    select 1
    from cron.job
    where jobname = job_name
      and schedule = job_schedule
      and command = worker_command
      and active
  ) then
    raise exception 'the account deletion worker schedule was not installed';
  end if;
end;
$migration$;

commit;
