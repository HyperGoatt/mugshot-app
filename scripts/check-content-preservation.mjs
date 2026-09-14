#!/usr/bin/env node
// Read-only release guard. Never prints rows, credentials, or image URLs.
import fs from 'node:fs';
import pg from '../qa/pglite/node_modules/pg/lib/index.js';
const [mode, receiptPath] = process.argv.slice(2);
if (!['snapshot','verify'].includes(mode) || !receiptPath) throw Error('Usage: MUGSHOT_PRESERVATION_DATABASE_URL=... node scripts/check-content-preservation.mjs snapshot|verify receipt.json');
const url = process.env.MUGSHOT_PRESERVATION_DATABASE_URL;
if (!url) throw Error('Explicit MUGSHOT_PRESERVATION_DATABASE_URL required');
const host = new URL(url).hostname;
const quote = value => '"' + value.replaceAll('"','""') + '"';
const before = mode === 'verify' ? JSON.parse(fs.readFileSync(receiptPath,'utf8')) : null;
if (before && (before.version !== 1 || before.host !== host)) throw Error('Snapshot version or database host mismatch');
if (mode === 'snapshot' && fs.existsSync(receiptPath)) throw Error('Refusing to overwrite an existing baseline');
const ca = process.env.MUGSHOT_QA_SSL_CA_PATH;
const client = new pg.Client({connectionString:url,ssl:ca?{ca:fs.readFileSync(ca,'utf8'),rejectUnauthorized:true}:{rejectUnauthorized:false},connectionTimeoutMillis:15000});
const receipt = {version:1,host,captured_at:new Date().toISOString(),tables:[]};
try {
 await client.connect();
 await client.query('begin isolation level repeatable read read only');
 await client.query("set local statement_timeout = '60s'");
 const tables = before?.tables ?? (await client.query(`select n.nspname as schema,c.relname as name,array_agg(a.attname::text order by a.attnum) as columns
 from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid
 where c.relkind in ('r','p') and a.attnum>0 and not a.attisdropped and not c.relispartition
 and (n.nspname='public' or (n.nspname='auth' and c.relname in ('users','identities')) or (n.nspname='storage' and c.relname='objects'))
 group by n.nspname,c.relname order by n.nspname,c.relname`)).rows;
 if (!tables.length) throw Error('No protected tables found');
 for (const t of tables) {
  if (!Array.isArray(t.columns) || !t.columns.length) throw Error('Invalid column baseline');
  // Hash original columns only: additive columns do not conceal changed old data.
  const row = 'jsonb_build_array('+t.columns.map(quote).join(',')+')::text';
  const sql = `with hashes as (select encode(sha256(convert_to(${row},'UTF8')),'hex') as h from ${quote(t.schema)}.${quote(t.name)}) select count(*)::text as count,encode(sha256(convert_to(coalesce(string_agg(h,'' order by h),''),'UTF8')),'hex') as sha256 from hashes`;
  const result = (await client.query(sql)).rows[0];
  receipt.tables.push({...t,...result});
 }
 await client.query('commit');
 if (before) {
  const differences = receipt.tables.filter((t,i)=>t.count!==before.tables[i].count || t.sha256!==before.tables[i].sha256).map(t=>t.schema+'.'+t.name);
  if (differences.length) throw Error('STOP: changed content in '+differences.join(', ')+'; investigate before rollout, never auto-repair');
  console.log('PASS original columns and row counts unchanged across '+tables.length+' tables');
 } else {
  fs.writeFileSync(receiptPath,JSON.stringify(receipt,null,2),{mode:0o600,flag:'wx'});
  console.log('PASS read-only baseline captured for '+tables.length+' tables');
 }
} finally {await client.end();}
