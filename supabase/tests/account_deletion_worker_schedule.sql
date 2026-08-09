begin;

do $test$
declare
  configured_job cron.job%rowtype;
begin
  if (
    select count(*)
    from vault.secrets
    where name = 'mugshot_account_deletion_service_role'
  ) <> 1 then
    raise exception 'the account deletion worker Vault secret is missing or ambiguous';
  end if;

  select job.*
  into configured_job
  from cron.job job
  where job.jobname = 'mugshot-account-deletion-v3';

  if not found
     or configured_job.active is not true
     or configured_job.schedule <> '*/5 * * * *'
     or configured_job.command not like '%drain_deletions_v3%'
     or configured_job.command not like '%protocolVersion%3%'
     or configured_job.command not like '%vault.decrypted_secrets%'
     or configured_job.command like '%Bearer eyJ%'
     or configured_job.command like '%sb_secret_%' then
    raise exception 'the account deletion worker schedule is unsafe or incomplete';
  end if;
end;
$test$;

rollback;
