import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {branchConfiguration, fixture} from './home-branch-fixture.mjs';

// Real Auth, PostgREST, RPC and Storage transport on an identified data-less
// branch. The branch fixture refuses the production project and active cron.
const config = branchConfiguration(...process.argv.slice(2));
const {db, api, rpc, users} = await fixture(config);
const [friend, stranger] = users;
const ok = (result, label) => {
  assert(result.ok, `${label}: HTTP ${result.status} ${JSON.stringify(result.data)}`);
  return result.data;
};
const one = (result, label) => {
  const rows = ok(result, label);
  assert(Array.isArray(rows) && rows.length === 1, `${label}: expected one row`);
  return rows[0];
};

try {
  const suffix = randomUUID().slice(0, 8);
  const email = `trust${suffix}@example.invalid`;
  const password = randomUUID() + randomUUID();
  const created = ok(await api('/auth/v1/admin/users', config.SUPABASE_SERVICE_ROLE_KEY, {
    email, password, email_confirm: true,
    user_metadata: {displayName: 'Backend Trust QA'},
  }), 'create generated-handle account');
  const signedIn = ok(await api('/auth/v1/token?grant_type=password', null, {
    email, password,
  }), 'sign in generated-handle account');
  const owner = {id: created.id, token: signedIn.access_token};
  const generated = one(await api(
    `/rest/v1/users?id=eq.${owner.id}&select=id,username,profile_username_confirmed_at`,
    owner.token, undefined, 'GET', {Accept: 'application/json'},
  ), 'read generated profile');
  assert.match(generated.username, /^[a-z0-9_]{3,30}$/);
  assert.equal(generated.profile_username_confirmed_at, null);

  const chosen = `trustqa_${suffix}`;
  const confirmed = ok(await rpc('complete_profile_setup_v1', owner, {
    p_display_name: 'Backend Trust QA', p_username: chosen,
  }), 'choose public username');
  assert.equal(confirmed.username, chosen);
  const currentLink = ok(await rpc('get_profile_link_v1', null, {
    p_slug: `@${chosen}`,
  }), 'resolve current profile link');
  const oldLink = ok(await rpc('get_profile_link_v1', null, {
    p_slug: `@${generated.username}`,
  }), 'resolve previous profile link');
  assert.equal(currentLink?.profile?.id, owner.id);
  assert.equal(oldLink?.profile?.id, owner.id);
  assert.equal(currentLink.profile.username, chosen);

  const people = ok(await rpc('search_people_v2', friend, {
    p_query: chosen, p_limit: 20,
  }), 'find changed username');
  assert(people.some(person => person.id === owner.id && person.username === chosen));
  ok(await rpc('block_user', friend, {p_blocked_user_id: owner.id}), 'block owner');
  const hidden = ok(await rpc('search_people_v2', friend, {
    p_query: chosen, p_limit: 20,
  }), 'search blocked owner');
  assert(!hidden.some(person => person.id === owner.id));
  ok(await rpc('unblock_user', friend, {p_blocked_user_id: owner.id}), 'unblock owner');
  console.log('PASS generated username, explicit change, old/current links, People search and block filtering');

  const cafeID = randomUUID();
  const cafeName = `Trust QA cafe ${suffix}`;
  const cafe = one(await api('/rest/v1/cafes?select=id,name,address', owner.token, {
    id: cafeID, name: cafeName, address: 'QA-only address',
    latitude: 40.1, longitude: -73.9,
  }, 'POST', {Prefer: 'return=representation'}), 'cafe INSERT RETURNING');
  assert.equal(cafe.id, cafeID);
  const hiddenCafe = ok(await api(
    `/rest/v1/cafes?id=eq.${cafeID}&select=id`, stranger.token,
    undefined, 'GET', {Accept: 'application/json'},
  ), 'stranger cafe lookup');
  assert.deepEqual(hiddenCafe, []);

  const visitID = randomUUID();
  const visit = one(await api('/rest/v1/visits?select=id,user_id,cafe_id,visibility,upload_state',
    owner.token, {
      id: visitID, user_id: owner.id, cafe_id: cafeID,
      drink_type: 'Coffee', drink_subtype: 'Espresso', caption: 'QA-only sip',
      visibility: 'private', context_type: 'Cafe', location_name: cafeName,
      upload_state: 'complete', overall_score: 4, ratings: {},
    }, 'POST', {Prefer: 'return=representation'}), 'cafe-backed visit INSERT RETURNING');
  assert.equal(visit.id, visitID);
  assert.equal(visit.cafe_id, cafeID);
  const ownerPost = ok(await api(`/rest/v1/visits?id=eq.${visitID}&select=id`,
    owner.token, undefined, 'GET', {Accept: 'application/json'}), 'owner post lookup');
  assert.equal(ownerPost.length, 1);
  const strangerPost = ok(await api(`/rest/v1/visits?id=eq.${visitID}&select=id`,
    stranger.token, undefined, 'GET', {Accept: 'application/json'}), 'stranger post lookup');
  assert.deepEqual(strangerPost, []);
  const duplicate = await api('/rest/v1/visits?select=id', owner.token, {
    id: visitID, user_id: owner.id, cafe_id: cafeID,
    drink_type: 'Coffee', drink_subtype: 'Espresso', caption: 'QA-only sip',
    visibility: 'private', context_type: 'Cafe', location_name: cafeName,
    upload_state: 'complete', overall_score: 4, ratings: {},
  }, 'POST', {Prefer: 'return=representation'});
  assert([400, 409].includes(duplicate.status), 'duplicate visit insert should fail');
  const visitRows = await db.query('select count(*)::int n from public.visits where id=$1', [visitID]);
  assert.equal(visitRows.rows[0].n, 1);

  const path = `${owner.id}/${visitID}/${randomUUID()}.jpg`;
  const bytes = Buffer.from('/9j/4AAQSkZJRgABAQEAYABgAAD/2Q==', 'base64');
  const upload = await fetch(`${config.SUPABASE_URL}/storage/v1/object/visit-photos-private/${path}`, {
    method: 'POST', signal: AbortSignal.timeout(20000),
    headers: {apikey: config.SUPABASE_ANON_KEY, Authorization: `Bearer ${owner.token}`,
      'Content-Type': 'image/jpeg'}, body: bytes,
  });
  assert(upload.ok, `private visit photo upload: HTTP ${upload.status}`);
  const download = user => fetch(
    `${config.SUPABASE_URL}/storage/v1/object/authenticated/visit-photos-private/${path}`,
    {signal: AbortSignal.timeout(20000), headers: {
      apikey: config.SUPABASE_ANON_KEY, Authorization: `Bearer ${user.token}`,
    }},
  );
  const ownedPhoto = await download(owner);
  assert(ownedPhoto.ok, `owner photo download: HTTP ${ownedPhoto.status}`);
  assert.deepEqual(Buffer.from(await ownedPhoto.arrayBuffer()), bytes);
  assert(!(await download(stranger)).ok, 'stranger read private photo');
  console.log('PASS cafe-backed publication, private visibility, duplicate prevention and private Storage');
} finally {
  await db.end();
}
