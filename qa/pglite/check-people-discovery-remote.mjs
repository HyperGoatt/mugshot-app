import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {branchConfiguration,fixture} from './home-branch-fixture.mjs';

const config=branchConfiguration(...process.argv.slice(2));
const {db,api,rpc,users}=await fixture(config);
const [owner,contact]=users;
const ok=result=>{assert(result.ok,JSON.stringify(result.data));return result.data;};
const first=value=>Array.isArray(value)?value[0]:value;

const invokeContact=async(user,body)=>{
  const response=await fetch(`${config.SUPABASE_URL}/functions/v1/match-selected-contacts-v1`,{
    method:'POST',signal:AbortSignal.timeout(20000),headers:{
      apikey:config.SUPABASE_ANON_KEY,
      Authorization:`Bearer ${user.token}`,
      'Content-Type':'application/json'
    },body:JSON.stringify(body)
  });
  const text=await response.text();
  let data;try{data=JSON.parse(text);}catch{data=text;}
  return {status:response.status,ok:response.ok,data,headers:response.headers};
};

const setPreferences=async(user,emailDiscoverable)=>first(ok(await rpc(
  'set_discovery_preferences_v1',user,{
    p_email_discoverable:emailDiscoverable,
    p_suggestions_enabled:true,
    p_mutual_explanations_enabled:true,
    p_consent_version:1,
    p_expected_version:null
  }
)));

const enroll=async user=>{
  const result=await invokeContact(user,{action:'enroll_email',consent_version:1});
  assert.equal(result.status,200,JSON.stringify(result.data));
  assert.equal(result.data.enrolled,true);
};

const match=async(user,email)=>{
  const result=await invokeContact(user,{
    action:'match',consent_version:1,
    items:[{item_key:'qa_contact_01',emails:[email]}]
  });
  assert.equal(result.status,200,JSON.stringify(result.data));
  assert.match(result.headers.get('cache-control')??'',/no-store/);
  return result.data.items[0].matches;
};

const landing=async token=>fetch(
  `${config.SUPABASE_URL}/functions/v1/friend-invite/${encodeURIComponent(token)}`,
  {signal:AbortSignal.timeout(20000),headers:{apikey:config.SUPABASE_ANON_KEY}}
);

try {
  await db.query(`update private.discovery_capabilities set enabled=true,updated_at=now()
    where capability in ('contact_matching','invitations')`);
  await setPreferences(owner,true);
  await setPreferences(contact,true);
  await enroll(owner);
  await enroll(contact);

  assert.equal((await match(owner,contact.email))[0].id,contact.id);
  ok(await rpc('block_user',owner,{p_blocked_user_id:contact.id}));
  assert.deepEqual(await match(owner,contact.email),[]);
  ok(await rpc('unblock_user',owner,{p_blocked_user_id:contact.id}));

  await setPreferences(contact,false);
  assert.equal((await db.query(
    `select count(*)::int n from private.discovery_identifiers where user_id=$1`,
    [contact.id]
  )).rows[0].n,0);
  assert.deepEqual(await match(owner,contact.email),[]);
  await setPreferences(contact,true);
  await enroll(contact);
  assert.equal((await match(owner,contact.email))[0].id,contact.id);
  console.log('PASS contact enrollment, matching, opt-out deletion and block filtering');

  const invite=first(ok(await rpc('create_friend_invite_v1',owner,{
    p_request_nonce:randomUUID()
  })));
  const liveLanding=await landing(invite.token);
  assert.equal(liveLanding.status,200);
  assert.match(liveLanding.headers.get('cache-control')??'',/no-store/);
  assert.match(await liveLanding.text(),/invited you to connect on Mugshot/);
  const resolved=first(ok(await rpc('resolve_friend_invite_v1',contact,{
    p_secret:invite.token
  })));
  assert.equal(resolved.user_id,owner.id);
  ok(await rpc('revoke_friend_invite_v1',owner,{p_invite_id:invite.invite_id}));
  assert.equal((await landing(invite.token)).status,404);

  const expiring=first(ok(await rpc('create_friend_invite_v1',owner,{
    p_request_nonce:randomUUID()
  })));
  await db.query(`update private.friend_invites set expires_at=now()-interval '1 second'
    where id=$1`,[expiring.invite_id]);
  assert.equal((await landing(expiring.token)).status,404);
  console.log('PASS invite landing, authenticated resolution, revocation and expiry');

  await db.query(`update private.discovery_capabilities set enabled=false,updated_at=now()
    where capability in ('contact_matching','invitations')`);
  const disabled=await invokeContact(owner,{action:'enroll_email',consent_version:1});
  assert.equal(disabled.status,503,JSON.stringify(disabled.data));
  console.log('PASS explicit capability rollback and Edge kill-switch behavior');
} finally {
  await db.query('update private.discovery_capabilities set enabled=false,updated_at=now()');
  await db.end();
}
