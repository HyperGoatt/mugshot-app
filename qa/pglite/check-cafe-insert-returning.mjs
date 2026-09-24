import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const owner = '10000000-0000-4000-8000-000000000001'
const stranger = '10000000-0000-4000-8000-000000000002'
const cafeID = '20000000-0000-4000-8000-000000000001'

try {
  await db.exec(`
    create role anon;
    create role authenticated;
    create role service_role bypassrls;
    create schema auth;
    create schema private;

    create table auth.users (
      id uuid primary key,
      deleted_at timestamptz
    );

    create function auth.uid()
    returns uuid
    language sql
    stable
    as $$
      select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
    $$;

    create function private.is_live_account_as(p_user_id uuid)
    returns boolean
    language sql
    stable
    security definer
    set search_path = ''
    as $$
      select p_user_id is not null and exists (
        select 1
        from auth.users account
        where account.id = p_user_id
          and account.deleted_at is null
      )
    $$;

    create function public.is_live_account(p_user_id uuid)
    returns boolean
    language sql
    stable
    security definer
    set search_path = ''
    as $$ select private.is_live_account_as(p_user_id) $$;

    create table public.cafes (
      id uuid primary key,
      name text not null,
      address text,
      city text,
      country text,
      latitude double precision,
      longitude double precision,
      apple_place_id text,
      apple_maps_place_id text,
      google_place_id text,
      website_url text,
      identity_key text
    );

    create table private.cafe_catalog_admission (
      cafe_id uuid primary key references public.cafes(id) on delete cascade,
      submitted_by uuid references auth.users(id) on delete set null,
      verified_at timestamptz,
      provider text check (provider in ('apple', 'google'))
    );

    create function private.track_cafe_admission_v1()
    returns trigger
    language plpgsql
    security definer
    set search_path = ''
    as $$
    begin
      if tg_op = 'INSERT' then
        insert into private.cafe_catalog_admission(cafe_id, submitted_by)
        values(new.id, auth.uid());
      else
        update private.cafe_catalog_admission
        set verified_at = null, provider = null
        where cafe_id = new.id;
      end if;
      return null;
    end;
    $$;

    create trigger cafe_catalog_admission_insert
    after insert on public.cafes
    for each row execute function private.track_cafe_admission_v1();

    create function private.can_read_cafe_catalog_as(p_cafe uuid, p_viewer uuid)
    returns boolean
    language sql
    stable
    security definer
    set search_path = ''
    as $$
      select exists (
        select 1
        from private.cafe_catalog_admission admission
        where admission.cafe_id = p_cafe
          and (
            admission.verified_at is not null
            or admission.submitted_by = p_viewer
          )
      )
    $$;

    create function public.can_read_cafe_catalog_v1(p_cafe uuid)
    returns boolean
    language sql
    stable
    security definer
    set search_path = ''
    as $$ select private.can_read_cafe_catalog_as(p_cafe, auth.uid()) $$;

    alter table public.cafes enable row level security;
    grant select on public.cafes to anon, authenticated;
    grant insert on public.cafes to authenticated;
    create policy "Cafe catalog authorized contexts"
      on public.cafes for select to anon, authenticated
      using (public.can_read_cafe_catalog_v1(id));
    create policy "Live accounts can submit cafes"
      on public.cafes for insert to authenticated
      with check (public.is_live_account(auth.uid()));

    insert into auth.users(id) values ('${owner}'), ('${stranger}');
  `)

  const migration = await fs.readFile(
    new URL(
      '../../supabase/migrations/20260924153000_repair_cafe_insert_returning.sql',
      import.meta.url,
    ),
    'utf8',
  )
  await db.exec(migration)

  await db.exec(`
    select set_config('request.jwt.claim.sub', '${owner}', false);
    set role authenticated;
  `)
  const inserted = await db.query(`
    insert into public.cafes(id, name, address)
    values ('${cafeID}', 'Synthetic cafe', '1 Example Ave')
    returning id, name
  `)
  assert.deepEqual(inserted.rows, [{ id: cafeID, name: 'Synthetic cafe' }])

  await db.exec('reset role')
  const admission = await db.query(`
    select submitted_by
    from private.cafe_catalog_admission
    where cafe_id = '${cafeID}'
  `)
  assert.equal(admission.rows[0].submitted_by, owner)

  await db.exec(`
    select set_config('request.jwt.claim.sub', '${stranger}', false);
    set role authenticated;
  `)
  const hidden = await db.query(`select id from public.cafes where id = '${cafeID}'`)
  assert.equal(hidden.rows.length, 0, 'unverified cafe remains hidden from another account')

  console.log('PASS cafe INSERT RETURNING recovery and private admission visibility')
} catch (error) {
  console.error(error.message)
  process.exitCode = 1
} finally {
  await db.close()
}
