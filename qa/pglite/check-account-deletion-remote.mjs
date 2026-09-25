import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {randomBytes, randomUUID} from 'node:crypto';
import {mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import pg from 'pg';
import {branchConfiguration} from './home-branch-fixture.mjs';

// Disposable branch only. This configures a QA-only direct worker bearer;
// cron remains disabled and no real provider or analytics destination is used.
const config = branchConfiguration(...process.argv.slice(2));
const db = new pg.Client({connectionString: config.sqlURL,
  ssl: {rejectUnauthorized: false}, connectionTimeoutMillis: 20000,
  application_name: 'mugshot_deletion_acceptance'});
await db.connect();
const workerSecret = randomBytes(32).toString('base64url');
const temp = mkdtempSync(join(tmpdir(), 'mugshot-deletion-qa-'));
try {
  const active = await db.query('select count(*)::int n from cron.job where active');
  assert.equal(active.rows[0].n, 0, 'QA schedules must be disabled');
  const secretsFile = join(temp, 'qa.env');
  writeFileSync(secretsFile, [
    `ACCOUNT_DELETION_WORKER_SECRET=${workerSecret}`,
    'ACCOUNT_DELETION_WORKER_SCHEDULED=true',
    'ACCOUNT_DELETION_LIVE_SESSION_GATE=true',
    'ACCOUNT_DELETION_STEP_UP_CLIENT_READY=true',
    'POSTHOG_ERASURE_ENABLED=false',
  ].join('\n') + '\n', {mode: 0o600});
  execFileSync('npx', ['--yes', 'supabase@2.109.1', 'secrets', 'set',
    '--project-ref', config.SUPABASE_URL.replace(/^https:\/\/|\.supabase\.co$/g, ''),
    '--env-file', secretsFile], {stdio: 'pipe'});

  const call = async (route, token, body, method = 'POST') => {
    const response = await fetch(`${config.SUPABASE_URL}${route}`, {
      method, signal: AbortSignal.timeout(20000),
      headers: {apikey: config.SUPABASE_ANON_KEY,
        ...(token ? {Authorization: `Bearer ${token}`} : {}),
        'Content-Type': 'application/json'},
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await response.text();
    let data;
    try { data = JSON.parse(text); } catch { data = text; }
    return {status: response.status, ok: response.ok, data};
  };
  const edge = (token, body, method = 'POST') => call(
    '/functions/v1/delete-account', token, body, method,
  );
  const ok = (result, label) => {
    assert(result.ok, `${label}: HTTP ${result.status} ${JSON.stringify(result.data)}`);
    return result.data;
  };
  const capability = ok(await edge(null, undefined, 'GET'), 'deletion capability');
  assert.equal(capability.automaticCleanupScheduled, true);
  assert.equal(capability.liveSessionGateConfigured, true);
  assert.equal(capability.stepUpClientConfigured, true);
  const deniedWorker = await edge(randomBytes(32).toString('base64url'), {
    action: 'drain_deletions_v3', protocolVersion: 3,
  });
  assert.equal(deniedWorker.status, 401);
  ok(await edge(workerSecret, {
    action: 'drain_deletions_v3', protocolVersion: 3,
  }), 'direct empty QA worker');

  const suffix = randomUUID().slice(0, 8);
  const email = `delete${suffix}@example.invalid`;
  const password = randomUUID() + randomUUID();
  const created = ok(await call('/auth/v1/admin/users', config.SUPABASE_SERVICE_ROLE_KEY, {
    email, password, email_confirm: true,
    user_metadata: {displayName: 'Deletion QA'},
  }), 'create deletion account');
  const initial = ok(await call('/auth/v1/token?grant_type=password', null,
    {email, password}), 'initial sign-in');
  ok(await call('/rest/v1/rpc/complete_profile_setup_v1', initial.access_token,
    {p_display_name: 'Deletion QA', p_username: `deleteqa_${suffix}`}),
  'complete deletion profile');
  const visitID = randomUUID();
  ok(await call('/rest/v1/visits', initial.access_token, {
    id: visitID, user_id: created.id, drink_type: 'Coffee',
    drink_subtype: 'Deletion QA sip', caption: '', visibility: 'private',
    context_type: 'Home', location_name: 'Home', upload_state: 'complete',
    overall_score: 0, ratings: {},
  }), 'create owned post');
  const path = `${created.id}/${visitID}/${randomUUID()}.jpg`;
  const bytes = Buffer.from('/9j/4AAQSkZJRgABAQEAYABgAAD/2Q==', 'base64');
  const upload = await fetch(`${config.SUPABASE_URL}/storage/v1/object/visit-photos-private/${path}`, {
    method: 'POST', signal: AbortSignal.timeout(20000),
    headers: {apikey: config.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${initial.access_token}`, 'Content-Type': 'image/jpeg'},
    body: bytes,
  });
  assert(upload.ok, `owned photo upload: HTTP ${upload.status}`);
  console.log('PASS deletion preflight has owned profile, post and private Storage object');

  const requestId = randomUUID();
  const recoverySecret = randomBytes(32).toString('base64url');
  const base = {protocolVersion: 3, requestId,
    expectedSubjectId: created.id, recoverySecret};
  const challenge = ok(await edge(initial.access_token, {
    ...base, action: 'begin_delete_step_up_v3',
  }), 'begin step-up');
  const sameSession = await edge(initial.access_token, {
    ...base, action: 'authorize_delete_step_up_v3',
    challengeId: challenge.challengeId,
  });
  assert.equal(sameSession.status, 403, 'initiating session authorized deletion');
  const fresh = ok(await call('/auth/v1/token?grant_type=password', null,
    {email, password}), 'fresh sign-in after challenge');
  const authorization = ok(await edge(fresh.access_token, {
    ...base, action: 'authorize_delete_step_up_v3',
    challengeId: challenge.challengeId,
  }), 'authorize fresh session');
  let deletion = ok(await edge(fresh.access_token, {
    ...base, action: 'delete_v3', challengeId: challenge.challengeId,
    authorizationSecret: authorization.authorizationSecret,
  }), 'request deletion');
  for (let attempt = 0; attempt < 6 && deletion.status !== 'completed'; attempt++) {
    ok(await edge(workerSecret, {
      action: 'drain_deletions_v3', protocolVersion: 3,
    }), 'direct QA worker retry');
    deletion = ok(await edge(null, {
      ...base, action: 'resume_delete_v3',
    }), 'resume deletion');
  }
  assert.equal(deletion.status, 'completed', 'account deletion did not finish');
  assert.equal((await db.query('select count(*)::int n from auth.users where id=$1',
    [created.id])).rows[0].n, 0);
  assert.equal((await db.query('select count(*)::int n from public.users where id=$1',
    [created.id])).rows[0].n, 0);
  assert.equal((await db.query('select count(*)::int n from public.visits where id=$1',
    [visitID])).rows[0].n, 0);
  assert.equal((await db.query('select count(*)::int n from storage.objects where bucket_id=$1 and name=$2',
    ['visit-photos-private', path])).rows[0].n, 0);
  const acknowledgement = ok(await edge(null, {
    ...base, action: 'acknowledge_delete_v3',
  }), 'acknowledge deletion');
  assert.equal(acknowledgement.acknowledged, true);
  const repeatedAcknowledgement = ok(await edge(null, {
    ...base, action: 'acknowledge_delete_v3',
  }), 'repeat deletion acknowledgement');
  assert.equal(repeatedAcknowledgement.acknowledged, true);
  assert.equal(repeatedAcknowledgement.receiptExpiresAt,
    acknowledgement.receiptExpiresAt, 'retry extended deletion receipt retention');
  console.log('PASS fresh-session deletion, direct worker, identity/post/media removal and acknowledgement');
} finally {
  rmSync(temp, {recursive: true, force: true});
  await db.end();
}
