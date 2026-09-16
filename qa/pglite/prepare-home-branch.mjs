import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import pg from 'pg';

// Explicit, disposable branch only. Credentials stay in process memory.
const [branchID, expectedRef] = process.argv.slice(2);
if (!branchID || !/^[a-z]{20}$/.test(expectedRef ?? '') || expectedRef === 'quskamnfwglctqewwfln') {
  throw new Error('An explicit non-production branch ID and project reference are required');
}
const config = JSON.parse(execFileSync('npx', ['--yes', 'supabase@2.109.1', 'branches', 'get', branchID, '--output', 'json'], { encoding: 'utf8' }));
const url = new URL(config.POSTGRES_URL_NON_POOLING);
if (url.hostname !== `db.${expectedRef}.supabase.co` || new URL(config.SUPABASE_URL).hostname !== `${expectedRef}.supabase.co`) {
  throw new Error('Branch identity mismatch');
}
const sessionURL = new URL(config.POSTGRES_URL);
if (!sessionURL.hostname.endsWith('.pooler.supabase.com') || sessionURL.username !== `postgres.${expectedRef}`) {
  throw new Error('Session pooler identity mismatch');
}
sessionURL.port = '5432';
const client = new pg.Client({ connectionString: sessionURL.href, ssl: { rejectUnauthorized: false }, application_name: 'mugshot_isolated_replay' });
await client.connect();
try {
  const root = path.resolve(import.meta.dirname, '../../supabase/migrations');
  const files = fs.readdirSync(root).filter(name => name.endsWith('.sql')).sort();
  const applied = new Set((await client.query('select version from supabase_migrations.schema_migrations')).rows.map(row => row.version));
  const local = new Set(files.map(name => name.slice(0, 14)));
  if ([...applied].some(version => !local.has(version))) throw new Error('Unknown remote migration; refusing replay');
  const pending = files.filter(name => !applied.has(name.slice(0, 14)));
  await client.query('begin');
  await client.query("set local lock_timeout = '5s'");
  // Operational placeholders satisfy historical scheduler prerequisites. No
  // real service credential is copied; every schedule is disabled before commit.
  for (const [name, value] of [
    ['mugshot_account_deletion_service_role', randomUUID()],
    ['mugshot_activity_delivery_service_role', randomUUID()],
    ['mugshot_activity_delivery_worker_url', `https://${expectedRef}.supabase.co/functions/v1/deliver-activity`]
  ]) {
    await client.query('select vault.create_secret($1,$2) where not exists(select 1 from vault.secrets where name=$2)', [value, name]);
  }
  for (const file of pending) {
    const original = fs.readFileSync(path.join(root, file), 'utf8');
    const sql = original.replace(/^\s*(?:begin|commit);\s*$/gim, '');
    await client.query(sql);
    await client.query('insert into supabase_migrations.schema_migrations(version,name,statements) values($1,$2,$3)',
      [file.slice(0,14), file.slice(15,-4), [original]]);
    console.log(`REPLAY ${file}`);
  }
  await client.query('select cron.alter_job(jobid,active := false) from cron.job where active');
  await client.query('commit');
  console.log(`PASS ${files.length} migrations aligned; ${pending.length} applied; scheduled work disabled`);
} catch (error) {
  await client.query('rollback');
  console.error(`Replay rolled back: ${error.message}`);
  process.exitCode = 1;
} finally { await client.end(); }
