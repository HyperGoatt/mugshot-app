-- Enable the bounded alpha cleanup scheduler only after the cleanup functions
-- and their service-role boundaries are present.

create extension if not exists pg_cron;

do $$
declare
  existing_job_id bigint;
  cleanup_command text :=
    'select public.purge_expired_recipe_staging_v3(1000); '
    'select public.purge_expired_collaboration_invites_v3(1000);';
begin
  if to_regprocedure('public.purge_expired_recipe_staging_v3(integer)') is null
     or to_regprocedure('public.purge_expired_collaboration_invites_v3(integer)') is null then
    raise exception 'alpha ephemera cleanup functions must exist before scheduling';
  end if;

  select jobid
  into existing_job_id
  from cron.job
  where jobname = 'mugshot-alpha-ephemera-v3'
  limit 1;

  if existing_job_id is null then
    perform cron.schedule(
      'mugshot-alpha-ephemera-v3',
      '*/15 * * * *',
      cleanup_command
    );
  else
    update cron.job
    set schedule = '*/15 * * * *',
        command = cleanup_command,
        active = true
    where jobid = existing_job_id;
  end if;

  if not exists (
    select 1
    from cron.job
    where jobname = 'mugshot-alpha-ephemera-v3'
      and schedule = '*/15 * * * *'
      and active
      and command = cleanup_command
  ) then
    raise exception 'alpha ephemera cleanup scheduler was not installed';
  end if;
end;
$$;
