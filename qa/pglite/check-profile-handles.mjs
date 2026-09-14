import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const joe = '10000000-0000-4000-8000-000000000001'
const other = '10000000-0000-4000-8000-000000000002'
const token = 'legacy-profile-token-1234567890'
try {
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth; create schema private;
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('test.actor', true), '')::uuid
    $$;
    create table public.users (id uuid primary key, username text, hidden boolean default false);
    create table public.profile_share_links (owner_id uuid references public.users on delete cascade, slug text, revoked_at timestamptz);
    create function private.profile_owner_visible_v2(subject uuid, viewer uuid) returns boolean
      language sql stable as $$ select exists(select 1 from public.users where id=subject and not hidden) $$;
    create function private.profile_projection_v4(subject uuid, viewer uuid) returns jsonb
      language sql stable as $$ select jsonb_build_object('owner',subject,'viewer',viewer) $$;
    insert into public.users(id,username) values ('${joe}','Joe'),('${other}','other');
    insert into public.profile_share_links values ('${joe}','${token}',null);
  `)
  await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260913023233_sprint1_readable_profile_links.sql', import.meta.url), 'utf8'))
  const owner = async (slug) => (await db.query('select private.profile_link_owner_v1($1) as owner', [slug])).rows[0].owner
  assert.equal(await owner('@JOE'), joe, 'case-insensitive current handle')
  assert.equal(await owner(token), joe, 'legacy token stays compatible')
  assert.equal(await owner('joe'), null, 'short handle requires internal discriminator')
  await db.query('update public.users set username=$1 where id=$2', ['new_joe', joe])
  assert.equal(await owner('@joe'), joe, 'old handle continues to the same owner')
  assert.equal(await owner('@new_joe'), joe)
  await assert.rejects(db.query('update public.users set username=$1 where id=$2', ['JOE', other]), /username unavailable/)
  await assert.rejects(db.query('update public.users set username=$1 where id=$2', ['bad-name', other]), /invalid username/)
  await db.query("select set_config('test.actor',$1,false)", [joe])
  assert.equal((await db.query('select public.get_my_profile_username_v1() as handle')).rows[0].handle, 'new_joe')
  assert.deepEqual((await db.query('select public.get_profile_link_v1($1) as profile',['@joe'])).rows[0].profile, { owner: joe, viewer: null }, 'signed-in sharing still uses the anonymous projection')
  await db.exec('update public.profile_share_links set revoked_at=now()')
  assert.equal(await owner(token), null, 'revoked token does not become a username link')
  await db.query('update public.users set hidden=true where id=$1', [joe])
  assert.equal(await owner('@joe'), null, 'unavailable owners cannot resolve')
  await db.query('delete from public.users where id=$1', [joe])
  assert.equal(await owner('@new_joe'), null, 'deleted profiles unavailable')
  await assert.rejects(db.query('update public.users set username=$1 where id=$2', ['new_joe', other]), /username unavailable/, 'deleted handles remain tombstoned')
  await db.query("select set_config('test.actor','',false)")
  await assert.rejects(db.query('select public.get_my_profile_username_v1()'), /authentication required/)
  for (const role of ['anon', 'authenticated']) {
    const permissions = (await db.query(`select
      has_function_privilege($1,'private.profile_link_owner_v1(text)','execute') as internal,
      has_table_privilege($1,'private.profile_handle_reservations','select') as reservations,
      has_function_privilege($1,'public.get_profile_link_v1(text)','execute') as projection`, [role])).rows[0]
    assert.deepEqual(permissions, {internal:false,reservations:false,projection:true})
  }
  console.log('PASS: profile handle aliases, tombstones, legacy revocation, anonymous projection and permissions')
} finally { await db.close() }
