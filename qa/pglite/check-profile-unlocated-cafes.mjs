import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const owner = '10000000-0000-4000-8000-000000000001'
const viewer = '10000000-0000-4000-8000-000000000002'

try {
  await db.exec(`
    create schema private;
    create function private.profile_owner_visible_v2(uuid, uuid)
      returns boolean language sql stable as $$
        select coalesce(current_setting('test.profile_denied', true), '') <> 'true'
      $$;
    create function private.profile_projection_v3(uuid, uuid)
      returns jsonb language sql stable as $$
        select jsonb_build_object(
          'profile', jsonb_build_object('id', $1, 'username', 'katmet'),
          'stats', jsonb_build_object('sips', 1),
          'top_cafes', jsonb_build_array(
            jsonb_build_object('id', 'first', 'latitude', null, 'longitude', null),
            jsonb_build_object('id', 'second', 'latitude', 32.78, 'longitude', -79.94)
          ),
          'highlight', jsonb_build_object('type', 'sip')
        )
      $$;
    create function private.profile_public_stats_v1(uuid)
      returns jsonb language sql stable as $$
        select jsonb_build_object('sips', 1, 'cafes', 1, 'friends', 2)
      $$;
    create function private.profile_favorite_spots_v1(uuid)
      returns jsonb language sql stable as $$ select '[]'::jsonb $$;
    create function private.profile_shows_friends_v1(uuid)
      returns boolean language sql stable as $$ select true $$;
  `)
  await db.exec(await fs.readFile(
    new URL('../../supabase/migrations/20260928153756_tolerate_unlocated_profile_cafes.sql', import.meta.url),
    'utf8'
  ))

  const projection = (await db.query(
    'select private.profile_projection_v4($1, $2) as profile', [owner, viewer]
  )).rows[0].profile
  assert.deepEqual(projection.top_cafes.map(cafe => cafe.id), ['second'])
  assert.equal(projection.profile.username, 'katmet')
  assert.deepEqual(projection.stats, { sips: 1, cafes: 1, friends: 2 })
  assert.equal(projection.profile_contract_version, 4)
  assert.equal('highlight' in projection, false)

  await db.query("select set_config('test.profile_denied', 'true', false)")
  const denied = (await db.query(
    'select private.profile_projection_v4($1, $2) as profile', [owner, viewer]
  )).rows[0].profile
  assert.equal(denied, null, 'profile authorization still fails closed')
  console.log('PASS: unlocated cafe summary excluded; profile content and authorization retained')
} finally {
  await db.close()
}
