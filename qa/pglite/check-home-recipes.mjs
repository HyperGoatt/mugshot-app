import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

// Minimal legacy recipe fixture. Access-helper outcomes are controlled here;
// existing social-policy suites cover its friendship/block/deletion semantics.
const db = new PGlite();
await db.exec(`
create role anon; create role authenticated;
create schema auth; create schema private;
create table auth.users(id uuid primary key);
create table public.visits(id uuid primary key,user_id uuid references auth.users,upload_state text default 'complete');
create function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create table public.recipe_identities(id uuid primary key,user_id uuid references auth.users,
 name text not null,updated_at timestamptz default now());
create table public.recipe_versions(id uuid primary key,recipe_identity_id uuid references public.recipe_identities,
 version_number integer not null,brew_details jsonb,visibility text default 'private',source_kind text,
 source_recipe_version_id uuid references public.recipe_versions,redistribution_allowed boolean default false,
 unique(recipe_identity_id,version_number));
create table public.home_test_access(version_id uuid,viewer uuid,allowed boolean);
create function private.can_project_recipe_version_as(v uuid,u uuid) returns boolean
 language sql stable as $$ select exists(select 1 from public.recipe_versions rv
 join public.recipe_identities ri on ri.id=rv.recipe_identity_id where rv.id=v and
 (ri.user_id=u or exists(select 1 from public.home_test_access a where a.version_id=v and a.viewer=u and a.allowed))) $$;
create function private.recipe_shared_brew_details_v1(details jsonb) returns jsonb language sql immutable as $$
 select jsonb_build_object('recipeName',details->'recipeName','steps','[]'::jsonb) $$;
create function private.can_view_visit_as(v uuid,u uuid) returns boolean language sql stable as $$
 select exists(select 1 from public.visits where id=v and user_id=u) $$;
create function public.configure_recipe_source_rights_v1(v uuid,kind text,reuse boolean,source uuid) returns text
 language plpgsql as $$ begin update public.recipe_versions set redistribution_allowed=reuse where id=v; return kind; end $$;
create function public.set_recipe_visibility_v1(v uuid,audience text,ack boolean) returns text
 language plpgsql as $$ begin update public.recipe_versions set visibility=audience where id=v; return audience; end $$;
grant usage on schema public,auth to authenticated;
`);
const migration = await readFile(new URL('../../supabase/migrations/20260915212702_home_recipe_workspace.sql', import.meta.url), 'utf8');
await db.exec(migration);
await db.exec(await readFile(new URL('../../supabase/migrations/20260916020417_home_recipe_http_conflicts.sql', import.meta.url), 'utf8'));
const projected = (await db.query('select private.home_recipe_public_content_v1($1) content', [{
  name: 'Safe recipe', privateNote: 'private', targets: { dose: 18, privateNote: 'private' },
  ingredients: [{ name: 'Syrup', recipe: { recipeID: randomUUID(), versionID: randomUUID(), instructions: 'private' }, privatePhotoPath: 'private' }],
  fields: [{ id: randomUUID(), label: 'Choice', choices: ['one', { privateNote: 'private' }] }],
  metricConfiguration: [{ metric: 'dose', label: 'Basket', isVisible: false, privateNote: 'private' }],
  coffee: { name: 'Beans', remainingWeight: 500, privatePhotoPath: 'private' },
  equipment: [{ role: 'grinder', displayName: 'Grinder', notes: 'private' }]
}])).rows[0].content;
assert.equal(JSON.stringify(projected).includes('private'), false, 'nested private payload fields must not escape');
assert.equal(projected.metricConfiguration[0].label, 'Basket');
assert.equal(projected.targets.dose, 18);
assert.deepEqual(projected.fields[0].choices, ['one']);
const owner = randomUUID(), other = randomUUID();
let activeOwner;
await db.query('insert into auth.users values ($1),($2)', [owner, other]);
const asUser = async id => {
  activeOwner = id;
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,false)", [id]);
  await db.exec('set role authenticated');
};
const save = async (revision, document, operation = randomUUID()) => (await db.query(
  'select public.save_home_workspace_v1($1,$2,$3,$4) result', [revision, operation, document, activeOwner])).rows[0].result;
const recipe = { id: randomUUID(), versions: [{ id: randomUUID(), number: 1,
  content: { name: '18g espresso', ingredients: [], targets: { dose: 18, ratio: 2 }, notes: 'Preparation only' } }] };
const document = { schemaVersion: 1, recipes: [recipe], attempts: [], sessions: [], recipeDrafts: [], attemptDrafts: [] };
await asUser(owner);
const operation = randomUUID();
const first = await save(0, document, operation);
assert.equal(first.revision, 1);
assert.equal((await save(0, document, operation)).revision, 1, 'same operation must not duplicate writes');
await assert.rejects(save(0, document), error => error.code === 'PT409' && /HOME_WORKSPACE_CONFLICT/.test(error.message));
const edit = structuredClone(document);
edit.recipes[0].versions[0].content.targets.dose = 20;
await assert.rejects(save(1, edit), /Immutable recipe version conflict/);
assert.equal((await db.query('select public.get_home_workspace_v1($1) result', [owner])).rows[0].result.revision, 1);
await asUser(other);
await assert.rejects(db.query('select public.save_home_workspace_v1($1,$2,$3,$4)', [0, randomUUID(), document, owner]), /Account mismatch/);
assert.equal((await db.query('select count(*)::int count from public.home_recipe_workspaces')).rows[0].count, 0);
await assert.rejects(save(0, document), /Recipe access denied/);
await assert.rejects(db.query('select public.get_home_recipe_content_v1($1)', [recipe.versions[0].id]), /Recipe access denied/);
const stolenLink = { id: randomUUID(), versions: [{ id: randomUUID(), number: 1,
 content: { name: 'Forbidden link', ingredients: [{ recipe: { recipeID: recipe.id, versionID: recipe.versions[0].id } }] } }] };
await assert.rejects(save(0, { ...document, recipes: [stolenLink] }), /Linked recipe access denied/);
await asUser(owner);
const cyclic = structuredClone(document);
cyclic.recipes[0].versions.push({ id: randomUUID(), number: 2,
 content: { name: 'Cycle', ingredients: [{ recipe: { recipeID: recipe.id, versionID: recipe.versions[0].id } }] } });
await assert.rejects(save(1, cyclic), /cannot form a cycle/);
const component = { id: randomUUID(), versions: [{ id: randomUUID(), number: 1,
 content: { name: 'Private syrup', ingredients: [], notes: 'Secret instructions' } }] };
const parent = { id: randomUUID(), versions: [{ id: randomUUID(), number: 1,
 content: { name: 'Latte', ingredients: [{ name: 'Syrup', recipe: { recipeID: component.id, versionID: component.versions[0].id } }] } }] };
await save(1, { ...document, recipes: [recipe, parent, component] });
await db.exec('reset role');
await db.query('insert into public.home_test_access values ($1,$2,true)', [parent.versions[0].id, other]);
await asUser(other);
const projection = (await db.query('select public.get_home_recipe_content_v1($1) result', [parent.versions[0].id])).rows[0].result;
assert.equal(projection.name, 'Latte');
assert.ok(!JSON.stringify(projection).includes('Secret instructions'));
await assert.rejects(db.query('select public.get_home_recipe_content_v1($1)', [component.versions[0].id]), /Recipe access denied/);
const deniedAdaptation = structuredClone(document);
deniedAdaptation.recipes = [{ id: randomUUID(), versions: [{ id: randomUUID(), number: 1,
 content: { name: 'Copy', ingredients: [], sourceVersionID: parent.versions[0].id } }] }];
await assert.rejects(save(0, deniedAdaptation), /reuse is not allowed/);
await db.exec('reset role');
await db.query("update public.recipe_versions set visibility='friends',redistribution_allowed=true,source_kind='original' where id=$1", [parent.versions[0].id]);
await asUser(other);
await assert.rejects(save(0, deniedAdaptation), /reuse is not allowed/, 'an old reuse flag does not grant new copies after audience narrows');
await db.exec('reset role');
const postID = randomUUID();
await db.query('insert into public.visits(id,user_id) values ($1,$2)', [postID,owner]);
await asUser(owner);
const attachments = [{ versionID: parent.versions[0].id, audience: 'friends', acknowledgesSharing: true }];
await db.query('select public.set_home_post_recipes_v1($1,$2,$3)', [postID,owner,attachments]);
await db.query('select public.set_home_post_recipes_v1($1,$2,$3)', [postID,owner,attachments]);
assert.equal((await db.query('select public.get_home_post_recipes_v1($1) result', [postID])).rows[0].result.length, 1);
await assert.rejects(db.query('select public.set_home_post_recipes_v1($1,$2,$3)', [postID,owner,[{...attachments[0],acknowledgesSharing:false}]]), /Confirm recipe sharing/);
await db.exec('reset role');
assert.equal((await db.query('select visibility from public.recipe_versions where id=$1', [component.versions[0].id])).rows[0].visibility, 'private');
await asUser(other);
await assert.rejects(db.query('select public.get_home_post_recipes_v1($1)', [postID]), /Post access denied/);
await assert.rejects(db.query('select public.set_home_post_recipes_v1($1,$2,$3)', [postID,other,attachments]), /Post access denied/);
await asUser(owner);
const ownAdaptation = { id: randomUUID(), versions: [{ id: randomUUID(), number: 1,
  content: { name: 'Latte variation', ingredients: [], sourceVersionID: parent.versions[0].id } }] };
const adaptedWorkspace = { ...document, recipes: [recipe, parent, component, ownAdaptation] };
await save(2, adaptedWorkspace);
const stripped = structuredClone(adaptedWorkspace);
stripped.recipes[3].versions.push({ id: randomUUID(), number: 2, content: { name: 'Unattributed copy', ingredients: [] } });
await assert.rejects(save(3, stripped), /source attribution must be preserved/);
await db.exec('reset role; set role anon');
await assert.rejects(db.query('select public.get_home_workspace_v1($1)', [owner]), /permission denied/);
await db.close();
console.log('PASS Home recipe owner isolation, immutable versions, CAS, retries, linked privacy, cycles, source rights');
