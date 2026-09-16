import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {branchConfiguration,fixture} from './home-branch-fixture.mjs';

const config=branchConfiguration(...process.argv.slice(2));
const {db,api,rpc,users}=await fixture(config);
const [owner,friend,stranger]=users;
const ok=result=>{assert(result.ok,JSON.stringify(result.data));return result.data;};
const denied=result=>assert([401,403].includes(result.status),`Expected authorization denial, received ${result.status}`);
try {
  await db.query('insert into public.friends(user_id,friend_user_id) values($1,$2),($2,$1)',[owner.id,friend.id]);
  const recipe=(name,template,method='other')=>({id:randomUUID(),versions:[{id:randomUUID(),number:1,
    content:{name,template,method,ingredients:[],targets:{},steps:[],servings:1,sourceURL:'',creatorCredit:'',tags:[],fields:[],notes:''}}]});
  const recipes=[recipe('Espresso','coffee','espresso'),recipe('Pour-over','coffee','pour_over'),recipe('Cold brew','coffee','cold_brew'),
    recipe('Syrup','component'),recipe('Latte','drink'),recipe('Custom','custom')];
  recipes[0].versions[0].content.targets={dose:18,ratio:2,seconds:28,calculation:'ratio'};
  recipes[1].versions[0].content.steps=[{instruction:'Bloom',waterGrams:60,waterMode:'cumulative',waitSeconds:40},
    {instruction:'Add',waterGrams:120,waterMode:'incremental'},{instruction:'Finish',waterGrams:300,waterMode:'cumulative',startSeconds:80}];
  recipes[2].versions[0].content.targets={dose:100,ratio:8,steepSeconds:57600,dilution:'1:1'};
  recipes[3].versions[0].content.notes='PRIVATE COMPONENT INSTRUCTIONS';
  recipes[4].versions[0].content.ingredients=[{name:'Syrup',amount:15,unit:'ml',recipe:{recipeID:recipes[3].id,versionID:recipes[3].versions[0].id}}];
  const attempt={id:randomUUID(),name:'Measured espresso',recipe:{recipeID:recipes[0].id,versionID:recipes[0].versions[0].id},
    targets:recipes[0].versions[0].content,actuals:{output:37.5},privateNote:'PRIVATE TASTE',nextTimeNote:'PRIVATE NEXT TIME'};
  const document={schemaVersion:1,recipes,attempts:[attempt],sessions:[],recipeDrafts:[],attemptDrafts:[]};
  const args={p_expected_revision:0,p_operation_id:randomUUID(),p_document:document,p_owner_id:owner.id};
  assert.equal(ok(await rpc('save_home_workspace_v1',owner,args)).revision,1);
  assert.equal(ok(await rpc('save_home_workspace_v1',owner,args)).revision,1);
  assert.equal((await rpc('save_home_workspace_v1',owner,{...args,p_operation_id:randomUUID()})).status,409);
  const loaded=ok(await rpc('get_home_workspace_v1',owner,{p_owner_id:owner.id}));
  assert.deepEqual(loaded.document.attempts[0].actuals,{output:37.5});
  assert.equal(loaded.document.recipes.length,6);
  denied(await rpc('get_home_workspace_v1',stranger,{p_owner_id:owner.id}));
  denied(await rpc('get_home_workspace_v1',null,{p_owner_id:owner.id}));
  denied(await rpc('save_home_workspace_v1',stranger,{...args,p_owner_id:stranger.id}));
  const changed=structuredClone(document);changed.recipes[0].versions[0].content.name='Overwrite';
  assert.equal((await rpc('save_home_workspace_v1',owner,{...args,p_expected_revision:1,p_operation_id:randomUUID(),p_document:changed})).status,409);
  console.log('PASS real Auth/Data API: six templates, targets/actuals, owner isolation, CAS, idempotence and immutable versions');

  const photoName=`${attempt.id}-${randomUUID()}.jpg`, path=`${owner.id}/home-attempts/${photoName}`;
  const bytes=Buffer.from('/9j/4AAQSkZJRgABAQEAYABgAAD/2Q==','base64');
  const upload=await fetch(`${config.SUPABASE_URL}/storage/v1/object/home-coffee-bag-photos/${path}`,{
    method:'POST',signal:AbortSignal.timeout(20000),headers:{apikey:config.SUPABASE_ANON_KEY,Authorization:`Bearer ${owner.token}`,'Content-Type':'image/jpeg','x-upsert':'true'},body:bytes});
  assert(upload.ok,`Photo upload ${upload.status}: ${await upload.text()}`);
  const download=async user=>fetch(`${config.SUPABASE_URL}/storage/v1/object/authenticated/home-coffee-bag-photos/${path}`,{
    signal:AbortSignal.timeout(20000),headers:{apikey:config.SUPABASE_ANON_KEY,Authorization:`Bearer ${user.token}`}});
  const own=await download(owner);assert(own.ok);assert.deepEqual(Buffer.from(await own.arrayBuffer()),bytes);
  assert(!(await download(stranger)).ok);
  console.log('PASS real private Storage upload, byte-identical download and cross-account denial');

  const version=recipes[4].versions[0].id, child=recipes[3].versions[0].id;
  denied(await rpc('get_home_recipe_content_v1',friend,{p_version_id:version}));
  const post={id:randomUUID()};
  ok(await api('/rest/v1/visits',owner.token,{id:post.id,user_id:owner.id,drink_type:'Coffee',drink_subtype:'QA Latte',
    caption:'QA Home recipe attachment',visibility:'friends',context_type:'Home',location_name:'Home',upload_state:'complete',overall_score:0,ratings:{}},'POST',{Prefer:'return=minimal'}));
  const attachments=[{versionID:version,audience:'friends',acknowledgesSharing:true}];
  denied(await rpc('set_home_post_recipes_v1',owner,{p_visit_id:post.id,p_owner_id:owner.id,p_attachments:[{...attachments[0],acknowledgesSharing:false}]}));
  for(let i=0;i<2;i++)ok(await rpc('set_home_post_recipes_v1',owner,{p_visit_id:post.id,p_owner_id:owner.id,p_attachments:attachments}));
  const projected=ok(await rpc('get_home_recipe_content_v1',friend,{p_version_id:version}));
  assert(!JSON.stringify(projected).includes('PRIVATE'));
  denied(await rpc('get_home_recipe_content_v1',friend,{p_version_id:child}));
  denied(await rpc('get_home_recipe_content_v1',stranger,{p_version_id:version}));
  assert.equal(ok(await rpc('get_home_post_recipes_v1',friend,{p_visit_id:post.id})).length,1);
  await db.query('insert into public.user_blocks(blocker_id,blocked_id) values($1,$2)',[owner.id,friend.id]);
  denied(await rpc('get_home_recipe_content_v1',friend,{p_version_id:version}));
  denied(await rpc('get_home_post_recipes_v1',friend,{p_visit_id:post.id}));
  const exported=ok(await rpc('build_owner_data_export_v4',owner,{}));
  assert.equal(exported.home_recipes_and_attempts.attempts[0].privateNote,'PRIVATE TASTE');
  console.log('PASS real publication: explicit consent, friend/stranger/block access, non-recursive components, attachment retries and owner export');
} finally {await db.end();}
