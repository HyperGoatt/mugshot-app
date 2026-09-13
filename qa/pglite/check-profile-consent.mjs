import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const author = '10000000-0000-4000-8000-000000000001'
const tagged = '10000000-0000-4000-8000-000000000002'
const visit = '20000000-0000-4000-8000-000000000001'
try {
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth; create schema private;
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('test.actor', true), '')::uuid
    $$;
    create table public.profile_visibility_preferences (
      user_id uuid primary key, show_friends_on_public_profile boolean not null default true,
      created_at timestamptz default now(), updated_at timestamptz default now()
    );
    create table public.visits (id uuid primary key, user_id uuid, visibility text, upload_state text);
    create function private.profile_owner_visible_v2(uuid,uuid) returns boolean
      language sql as $$ select true $$;
    create function private.has_active_moderation_action(text,uuid,text[]) returns boolean
      language sql as $$ select false $$;
    insert into public.profile_visibility_preferences(user_id) values ('${author}');
    insert into public.visits values ('${visit}', '${author}', 'friends', 'complete');
  `)
  await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260913020258_sprint1_profile_consent.sql', import.meta.url), 'utf8'))
  const visible = async () => (await db.query('select private.profile_visit_published_v1($1,$2) as visible', [visit, tagged])).rows[0].visible
  const actor = async (id) => db.query("select set_config('test.actor', $1, false)", [id])
  assert.equal(await visible(), false, 'legacy default-on does not establish consent')
  await actor(tagged)
  await db.query('select public.set_profile_friends_visibility_v2(true,1)')
  assert.equal(await visible(), false, 'tagged owner cannot publish author content')
  await actor(author)
  assert.equal((await db.query('select public.get_profile_friends_visibility_v2() as enabled')).rows[0].enabled, false)
  await assert.rejects(db.query('select public.set_profile_friends_visibility_v2(true,0)'), /consent/)
  await assert.rejects(db.query('select public.set_profile_friends_visibility_v1(true)'), /update Mugshot/)
  await db.query('select public.set_profile_friends_visibility_v2(true,1)')
  assert.equal((await db.query('select public.get_profile_friends_visibility_v2() as enabled')).rows[0].enabled, true)
  assert.equal(await visible(), true, 'both owners consented')
  await db.exec("update public.visits set visibility = 'private'")
  assert.equal(await visible(), false, 'Private never publishes')
  await db.exec("update public.visits set visibility = 'friends'")
  await db.query('select public.set_profile_friends_visibility_v1(false)')
  assert.equal(await visible(), false, 'older clients can withdraw consent')
  await db.exec("update public.visits set visibility = 'everyone'")
  assert.equal(await visible(), true, 'Everyone remains eligible without Friends consent')
  await db.exec("update public.visits set upload_state = 'pending'")
  assert.equal(await visible(), false, 'incomplete uploads stay hidden')
  await actor('')
  await assert.rejects(db.query('select public.set_profile_friends_visibility_v2(true,1)'), /authentication required/)
  const grant = await db.query("select has_function_privilege('anon','public.set_profile_friends_visibility_v2(boolean,integer)','execute') as allowed")
  assert.equal(grant.rows[0].allowed, false, 'anonymous callers cannot write consent')
  console.log('PASS: profile consent, legacy clients, tags, Private exclusion, auth and grants')
} finally {
  await db.close()
}
