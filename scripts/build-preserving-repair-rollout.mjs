#!/usr/bin/env node
// Generates a reviewable SQL artifact. It never connects to a database.
import fs from 'node:fs';
import assert from 'node:assert/strict';

const destination = process.argv[2];
assert.ok(destination, 'Usage: node scripts/build-preserving-repair-rollout.mjs output.sql');
assert.ok(!fs.existsSync(destination), 'Refusing to overwrite a rollout artifact');
const quote = value => "'" + value.replaceAll("'", "''") + "'";
const files = fs.readdirSync('supabase/migrations').filter(f =>
  f.endsWith('.sql') && (f.slice(0, 14) > '20260914023251')
).sort();
assert.equal(files.length, 3, 'Re-review the rollout when migration scope changes');
const sql = [`begin;
set local lock_timeout='5s';
set local statement_timeout='120s';
do $$ begin
 if (select count(*) from supabase_migrations.schema_migrations)<>164
 or (select max(version) from supabase_migrations.schema_migrations)<>'20260914023251'
 then raise exception 'Unexpected source migration history; stop rollout';end if;
end $$;
create temporary table rollout_original_fingerprints(schema_name text,table_name text,columns_sql text,row_count bigint,digest text) on commit drop;
create function pg_temp.capture_rollout_fingerprints() returns void language plpgsql as $$
declare t record; cols text; n bigint; h text;
begin
 for t in select ns.nspname,c.relname,c.oid from pg_class c join pg_namespace ns on ns.oid=c.relnamespace
 where c.relkind in ('r','p') and not c.relispartition and (ns.nspname='public' or
 (ns.nspname='auth' and c.relname in ('users','identities')) or (ns.nspname='storage' and c.relname='objects'))
 order by ns.nspname,c.relname loop
  execute format('lock table %I.%I in share row exclusive mode',t.nspname,t.relname);
  select string_agg(quote_ident(attname),',' order by attnum) into cols from pg_attribute where attrelid=t.oid and attnum>0 and not attisdropped;
  execute format('with hashes as (select encode(sha256(convert_to(jsonb_build_array(%s)::text,''UTF8'')),''hex'') h from %I.%I) select count(*),encode(sha256(convert_to(coalesce(string_agg(h,'''' order by h),''''),''UTF8'')),''hex'') from hashes',cols,t.nspname,t.relname) into n,h;
  insert into rollout_original_fingerprints values(t.nspname,t.relname,cols,n,h);
 end loop;
end $$;
select pg_temp.capture_rollout_fingerprints();
create temporary table rollout_original_activity on commit drop as select id,title,body,metadata from public.activity_events;
create temporary table rollout_original_buckets on commit drop as select id,public from storage.buckets;
`];
for (const file of files) {
  const original = fs.readFileSync('supabase/migrations/' + file, 'utf8');
  const lines = original.split('\n');
  const begins = lines.flatMap((line, i) => line.trim().toLowerCase() === 'begin;' ? [i] : []);
  const commits = lines.flatMap((line, i) => line.trim().toLowerCase() === 'commit;' ? [i] : []);
  if (begins.length || commits.length) {
    assert.equal(begins.length, 1); assert.equal(commits.length, 1);
    assert.ok(begins[0] < commits[0]);
    assert.ok([...lines.slice(0, begins[0]), ...lines.slice(commits[0] + 1)].every(l => !l.trim() || l.trim().startsWith('--')));
    lines[begins[0]] = ''; lines[commits[0]] = '';
  }
  sql.push('-- ' + file, lines.join('\n'));
  sql.push(`insert into supabase_migrations.schema_migrations(version,name,statements) values(${quote(file.slice(0,14))},${quote(file.slice(15,-4))},array[${quote(original)}]);`);
}
sql.push(`
do $$
declare t record; n bigint; h text;
begin
 for t in select * from rollout_original_fingerprints loop
  execute format('with hashes as (select encode(sha256(convert_to(jsonb_build_array(%s)::text,''UTF8'')),''hex'') h from %I.%I) select count(*),encode(sha256(convert_to(coalesce(string_agg(h,'''' order by h),''''),''UTF8'')),''hex'') from hashes',t.columns_sql,t.schema_name,t.table_name) into n,h;
  if n is distinct from t.row_count or h is distinct from t.digest then raise exception 'Preservation failed: %.%; entire rollout rolled back',t.schema_name,t.table_name;end if;
 end loop;
 if exists(select 1 from storage.buckets b join rollout_original_buckets o using(id) where b.public is distinct from o.public) then raise exception 'Bucket visibility changed';end if;
end $$;
select count(*) as preserved_original_tables from rollout_original_fingerprints;
commit;
`);
fs.writeFileSync(destination, sql.join('\n'), {mode:0o600,flag:'wx'});
console.log('Generated staged rollout for',files.length,'migrations; original-row and bucket preservation guards included.');
