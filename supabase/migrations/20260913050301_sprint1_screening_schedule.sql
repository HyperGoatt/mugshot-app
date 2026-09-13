-- Definition only: release configuration explicitly enables the schedule after
-- disclosures, no-training controls, secrets and isolated QA are verified.
create function private.dispatch_screening_worker_v1()
returns bigint language plpgsql security definer set search_path='' as $$
declare worker_url text; worker_secret text; request_id bigint;
begin
  if not exists(select 1 from private.screening_jobs where state='pending'
    and available_at<=now() and (lease_until is null or lease_until<=now())) then return null; end if;
  select decrypted_secret into strict worker_url from vault.decrypted_secrets where name='mugshot_screening_worker_url';
  select decrypted_secret into strict worker_secret from vault.decrypted_secrets where name='mugshot_screening_worker_secret';
  if worker_url is null or worker_secret is null or worker_url !~ '^https://[a-z]{20}\.supabase\.co/functions/v1/screen-content$'
    or length(worker_secret) not between 32 and 512 then
    raise exception 'screening scheduler configuration invalid';
  end if;
  select net.http_post(url:=worker_url,headers:=jsonb_build_object(
    'Content-Type','application/json','x-screening-secret',worker_secret),
    body:='{}'::jsonb,timeout_milliseconds:=50000) into request_id;
  return request_id;
end;
$$;
revoke all on function private.dispatch_screening_worker_v1() from public,anon,authenticated,service_role;

create function public.configure_screening_schedule_v1(p_enabled boolean)
returns boolean language plpgsql security definer set search_path='' as $$
declare existing record; worker_url text; worker_secret text;
begin
  if p_enabled is null then raise exception 'screening schedule state required'; end if;
  if (select count(*) from cron.job where jobname='mugshot-screening-v1')>1 then
    raise exception 'ambiguous screening schedule';
  end if;
  if not p_enabled then
    for existing in select jobid from cron.job where jobname='mugshot-screening-v1' loop
      perform cron.unschedule(existing.jobid);
    end loop;
    return false;
  end if;
  select decrypted_secret into strict worker_url from vault.decrypted_secrets where name='mugshot_screening_worker_url';
  select decrypted_secret into strict worker_secret from vault.decrypted_secrets where name='mugshot_screening_worker_secret';
  if worker_url is null or worker_secret is null or worker_url !~ '^https://[a-z]{20}\.supabase\.co/functions/v1/screen-content$'
    or length(worker_secret) not between 32 and 512 then
    raise exception 'screening scheduler configuration invalid';
  end if;
  perform cron.schedule('mugshot-screening-v1','10 seconds','select private.dispatch_screening_worker_v1();');
  return true;
end;
$$;
revoke all on function public.configure_screening_schedule_v1(boolean) from public,anon,authenticated;
grant execute on function public.configure_screening_schedule_v1(boolean) to service_role;
