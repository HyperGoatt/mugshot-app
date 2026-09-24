begin;

-- PostgREST requests a representation after creating a cafe. The catalog
-- SELECT policy recognizes an unverified cafe through its private admission
-- row, but the original AFTER INSERT trigger created that row too late for
-- INSERT ... RETURNING. Create the admission first and defer its foreign-key
-- check until the cafe row exists later in the same statement.
alter table private.cafe_catalog_admission
  alter constraint cafe_catalog_admission_cafe_id_fkey
  deferrable initially deferred;

create or replace function private.track_cafe_admission_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into private.cafe_catalog_admission (cafe_id, submitted_by)
    values (new.id, auth.uid());
  else
    -- Any trusted correction withdraws the previous provider attestation. The
    -- verifier may attest the new canonical snapshot in the same transaction.
    update private.cafe_catalog_admission
    set verified_at = null,
        provider = null
    where cafe_id = new.id;
  end if;
  return new;
end;
$$;

revoke all on function private.track_cafe_admission_v1()
  from public, anon, authenticated;

drop trigger if exists cafe_catalog_admission_insert on public.cafes;
create trigger cafe_catalog_admission_insert
before insert on public.cafes
for each row execute function private.track_cafe_admission_v1();

-- The SELECT policy is evaluated by the same statement that fired the trigger.
-- VOLATILE makes the policy wrapper use a fresh command snapshot so it can see
-- the admission row created by the BEFORE trigger. The reusable private helper
-- and its authorization logic remain unchanged.
alter function public.can_read_cafe_catalog_v1(uuid) volatile;

commit;
