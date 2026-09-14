import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import {PGlite} from '@electric-sql/pglite'
const db=new PGlite()
const owner='10000000-0000-4000-8000-000000000001'
const friend='10000000-0000-4000-8000-000000000002'
const visit='20000000-0000-4000-8000-000000000001'
const comment='30000000-0000-4000-8000-000000000001'
try {
 await db.exec(`create role anon;create role authenticated;create role service_role;
 create schema private;create schema auth;create schema storage;
 create table storage.objects(id uuid primary key,bucket_id text,name text,metadata jsonb,version text,last_accessed_at timestamptz);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
 create table public.users(id uuid primary key,display_name text,username text,bio text,location text,favorite_drink text,instagram_handle text,avatar_url text,banner_url text);
 create table public.visits(id uuid primary key,user_id uuid references public.users,caption text,notes text,drink_type text,drink_subtype text,drink_type_custom text,location_name text,city_state text,ratings jsonb,category_scores jsonb,poster_photo_url text,visibility text,upload_state text,cafe_id uuid,brew_method text,equipment text,created_at timestamptz default now());
 create table public.visit_photos(id uuid primary key,visit_id uuid references public.visits on delete cascade,photo_url text);
 create table public.comments(id uuid primary key,user_id uuid references public.users,visit_id uuid references public.visits on delete cascade,text text,removed_at timestamptz);
 create table public.profile_favorite_spots(user_id uuid,position int,descriptor text,cafe_id uuid);
 create table public.cafes(id uuid primary key,name text,address text,city text,latitude double precision,longitude double precision,apple_maps_place_id text,apple_place_id text,website_url text);
 create table public.cafe_lists(id uuid primary key default gen_random_uuid(),owner_id uuid,title text,description text,visibility text,system_kind text,published_at timestamptz,updated_at timestamptz default now(),comments_enabled boolean default true,source_list_id uuid);
 create table public.cafe_list_items(id uuid primary key default gen_random_uuid(),list_id uuid references public.cafe_lists on delete cascade,cafe_id uuid,contributor_id uuid,note text,position int default 0,created_at timestamptz default now());
 create table public.cafe_list_comments(id uuid primary key,list_id uuid references public.cafe_lists on delete cascade,user_id uuid,body text,deleted_at timestamptz,created_at timestamptz default now());
 create table public.cafe_list_members(list_id uuid,user_id uuid,invitation_status text,role text,created_at timestamptz,updated_at timestamptz,accepted_at timestamptz,responded_at timestamptz,invited_by uuid);
 create table public.cafe_list_share_links(list_id uuid,slug text,revoked_at timestamptz,created_at timestamptz);
 create table public.cafe_list_follows(list_id uuid,user_id uuid);
 create table public.user_cafe_states(user_id uuid,cafe_id uuid,is_favorite boolean,want_to_try boolean);
 create table public.recipe_identities(id uuid primary key,user_id uuid,name text);
 create table public.recipe_versions(id uuid primary key,recipe_identity_id uuid references public.recipe_identities on delete cascade,version_number int,version_label text,brew_details jsonb,visibility text,source_visit_id uuid,brew_method text,equipment text,source_kind text,redistribution_allowed boolean,source_recipe_version_id uuid,created_at timestamptz default now());
 create table public.trusted_recommendations(id uuid primary key,sender_id uuid,recipient_id uuid,target_kind text,target_recipe_version_id uuid,target_cafe_id uuid,status text,note text,created_at timestamptz default now());
 create function private.is_public_cafe_list_as(uuid,uuid) returns boolean language sql as $$select false$$;
 create function private.can_socially_mutate_as(uuid) returns boolean language sql as $$select true$$;
 create function private.can_manage_cafe_list_as(uuid,uuid) returns boolean language sql as $$select false$$;
 create function private.cafe_list_profile_json_v2(uuid,uuid) returns jsonb language sql as $$select '{}'::jsonb$$;
 create table private.moderation_operators(user_id uuid,is_active boolean,role text default 'reviewer');
 create function private.is_live_account_as(id uuid) returns boolean language sql stable as $$select exists(select 1 from public.users where users.id=$1)$$;
 create function private.blocked_between(uuid,uuid) returns boolean language sql stable as $$select coalesce(current_setting('test.blocked',true),'')='true'$$;
 create function private.confirmed_friends(uuid,uuid) returns boolean language sql stable as $$select true$$;
 create function private.has_active_moderation_action(text,uuid,text[]) returns boolean language sql stable as $$select coalesce(current_setting('test.hidden',true),'')='true'$$;
 create function private.profile_shows_friends_v1(uuid) returns boolean language sql stable as $$select coalesce(current_setting('test.consent',true),'')='true'$$;
 insert into public.users(id,display_name,username) values('${owner}','Synthetic owner','synthetic_owner'),('${friend}','Synthetic friend','synthetic_friend');
 insert into public.visits(id,user_id,caption,notes,drink_type_custom,location_name,poster_photo_url,visibility,upload_state) values('${visit}','${owner}','Shared caption','PRIVATE SENTINEL','Latte','Synthetic cafe',null,'friends','complete');
 insert into public.comments values('${comment}','${friend}','${visit}','Synthetic comment',null);
 `)
 for(const file of ['20260913025947_sprint1_screening_queue.sql','20260913030620_sprint1_primary_screening_gates.sql','20260913032223_sprint1_shared_collection_screening.sql','20260913042453_sprint1_private_collaboration_screening_exclusion.sql','20260913050554_sprint1_private_recipe_screening_exclusion.sql','20260913050851_sprint1_shared_drink_text_screening.sql','20260913054056_sprint1_recipe_recipient_authorization.sql','20260913072019_sprint1_shared_cafe_text_screening.sql','20260913073502_sprint1_shared_visit_display_text.sql']) await db.exec(await fs.readFile(new URL('../../supabase/migrations/'+file,import.meta.url),'utf8'))
 const allowed=async(name,...params)=>(await db.query(`select private.${name}(${params.map((_,i)=>'$'+(i+1)).join(',')}) as allowed`,params)).rows[0].allowed
 const approve=()=>db.exec("update private.screening_jobs set state='approved'")
 const snapshot=async(kind)=>(await db.query('select * from private.screening_jobs where subject_kind=$1 and subject_id=$2',[kind,kind==='visit'?visit:comment])).rows[0]
 assert.equal(await allowed('can_view_visit_as',visit,owner),true,'owner retains journal while pending')
 assert.equal(await allowed('can_view_visit_as',visit,friend),false,'friends cannot bypass pending')
 assert.equal(await allowed('profile_owner_visible_v2',owner,null),false,'anonymous pending profile returns false, never null')
 assert.equal(await allowed('is_capability_shareable_visit_v1',visit),false,'legacy links cannot bypass screening')
 assert(!JSON.stringify(await snapshot('visit')).includes('PRIVATE SENTINEL'),'private notes never queued')
 await approve()
 assert.equal(await allowed('can_view_visit_as',visit,friend),true)
 assert.equal(await allowed('can_view_comment_as',comment,owner),true)
 assert.equal(await allowed('is_capability_shareable_visit_v1',visit),true)
 assert.equal(await allowed('profile_visit_published_v1',visit,owner),false,'Friends profile consent still required')
 await db.exec("select set_config('test.consent','true',false)")
 assert.equal(await allowed('profile_visit_published_v1',visit,owner),true)
 await db.query("update public.visits set drink_type='Coffee',drink_subtype='Synthetic shared drink name' where id=$1",[visit])
 assert.equal((await snapshot('visit')).state,'pending','displayed drink edits require fresh screening')
 assert((await snapshot('visit')).payload.text.includes('Synthetic shared drink name'),'displayed subtype included in provider allowlist')
 assert((await snapshot('visit')).payload.text.includes('Coffee'),'displayed type included in provider allowlist')

 await db.query('update public.visits set city_state=$1,ratings=$2,category_scores=$3 where id=$4',[
   'Shared city label',{'Custom rating label':4},[{name:'Custom category label',score:4,weight:1,private_note:'NESTED PRIVATE RATING SENTINEL',id:'INTERNAL RATING ID'}],visit])
 const displayedText=(await snapshot('visit')).payload.text
 assert(displayedText.includes('Shared city label') && displayedText.includes('Custom rating label') && displayedText.includes('Custom category label'))
 assert(!displayedText.includes('NESTED PRIVATE RATING SENTINEL') && !displayedText.includes('INTERNAL RATING ID'),'only displayed rating labels enter screening')
 await approve()
 const displayedRevision=(await snapshot('visit')).revision
 await db.query('update public.visits set ratings=$1,category_scores=$2 where id=$3',[{'Custom rating label':2},[{name:'Custom category label',score:2,weight:0.5,private_note:'CHANGED PRIVATE RATING SENTINEL'}],visit])
 assert.equal((await snapshot('visit')).revision,displayedRevision,'numeric or hidden metadata changes do not send new text')
 await db.query('update public.visits set city_state=$1 where id=$2',['Changed shared city label',visit])
 assert.notEqual((await snapshot('visit')).revision,displayedRevision,'visible location edits invalidate approval')
 await approve()
 const original=await snapshot('visit')
 await db.query('update public.visits set notes=$1 where id=$2',['OTHER PRIVATE SENTINEL',visit])
 assert.equal((await snapshot('visit')).revision,original.revision,'private-only edit does not transmit or rescreen')
 await db.query('update public.visits set caption=$1 where id=$2',['Edited shared caption',visit])
 assert.notEqual((await snapshot('visit')).revision,original.revision)
 assert.equal(await allowed('can_view_visit_as',visit,friend),false,'edit held immediately')
 await approve()
 await db.query('insert into public.visit_photos values(gen_random_uuid(),$1,$2)',[visit,'https://example.invalid/new-photo.jpg'])
 assert.equal((await snapshot('visit')).state,'pending','new image invalidates approved revision')
 await approve()
 const mediaRef=`mugshot-storage://visit-photos-private/${owner}/${visit}/same%20photo.jpg`
 await db.query('update public.visits set poster_photo_url=$1 where id=$2',[mediaRef,visit])
 await db.query('insert into storage.objects values(gen_random_uuid(),$1,$2,$3,$4,now())',['visit-photos-private',`${owner}/${visit}/same photo.jpg`,{eTag:'one'},'v1'])
 await approve()
 const approvedMedia=await snapshot('visit')
 await db.exec('update storage.objects set last_accessed_at=now()')
 assert.equal((await snapshot('visit')).revision,approvedMedia.revision,'media reads do not rescreen')
 await db.exec("update storage.objects set version='v2'")
 assert.notEqual((await snapshot('visit')).revision,approvedMedia.revision,'same-path Storage overwrite invalidates approval')
 assert.equal((await snapshot('visit')).state,'pending')
 await db.query("update public.visits set visibility='private' where id=$1",[visit])
 assert.equal(await snapshot('visit'),undefined)
 assert.equal(await snapshot('comment'),undefined,'parent privacy removes comment payload')
 assert.equal(await allowed('can_view_visit_as',visit,owner),true)
 assert.equal(await allowed('can_view_visit_as',visit,friend),false)
 assert.equal(await allowed('is_capability_shareable_visit_v1',visit),false)
 await db.query("update public.visits set visibility='everyone' where id=$1",[visit])
 await approve()
 await db.exec("select set_config('test.blocked','true',false)")
 assert.equal(await allowed('can_view_visit_as',visit,friend),false,'screening approval never overrides blocks')
 await db.exec("select set_config('test.blocked','false',false); select set_config('test.hidden','true',false)")
 assert.equal(await allowed('profile_owner_visible_v2',owner,null),false,'enforcement returns false for anonymous')
 assert.equal(await allowed('is_capability_shareable_visit_v1',visit),false,'human removal still enforced')
 await db.query('delete from public.visits where id=$1',[visit])
 assert.equal(await snapshot('visit'),undefined)
 assert.equal(await snapshot('comment'),undefined)
 await db.exec("select set_config('test.hidden','false',false)")
 await db.exec(`create function private.cafe_list_summary_json_v2(uuid,uuid) returns jsonb language sql as $$select case when private.can_view_cafe_list_as($1,$2) then jsonb_build_object('id',$1) end$$;`)
 const list='40000000-0000-4000-8000-000000000001',item='50000000-0000-4000-8000-000000000001',cafe='60000000-0000-4000-8000-000000000001',listComment='70000000-0000-4000-8000-000000000001'
 await db.query('insert into public.cafes(id,name) values($1,$2)',[cafe,'Synthetic cafe'])
 await db.query("insert into public.cafe_lists(id,owner_id,title,visibility,published_at) values($1,$2,'Synthetic list','public',now())",[list,owner])
 await db.query("insert into public.cafe_list_items(id,list_id,cafe_id,contributor_id,note) values($1,$2,$3,$4,'Synthetic item note')",[item,list,cafe,friend])
 await db.query("insert into public.cafe_list_comments(id,list_id,user_id,body) values($1,$2,$3,'Synthetic list comment')",[listComment,list,friend])
 assert.equal(await allowed('is_public_cafe_list_as',list,null),false,'pending list stays private to owner')
 assert.equal(await allowed('can_view_cafe_list_as',list,owner),true,'owner retains list')
 await db.exec("update private.screening_jobs set state='approved' where subject_kind='list'")
 const publicList=async()=>(await db.query('select private.public_cafe_list_json_v1($1,null,true,true) as projection',[list])).rows[0].projection
 assert.equal((await publicList()).items.length,0,'unapproved item notes do not leak through public list JSON')
 assert.equal((await publicList()).comments.length,0,'unapproved list comments held')
 await db.query("select set_config('test.actor',$1,false)",[owner])
 assert.equal((await db.query('select public.get_cafe_list_v2($1) as projection',[list])).rows[0].projection.items.length,0,'legacy list RPC also gates another contributor note')
 await approve()
 assert.equal((await publicList()).items[0].caption,'Synthetic item note')
 assert.equal((await publicList()).comments[0].body,'Synthetic list comment')
 await db.query("update public.cafe_list_items set note='Edited item note' where id=$1",[item])
 assert.equal((await publicList()).items.length,0,'edited list note loses its approval')
 await db.query('update public.cafe_list_items set note=null where id=$1',[item])
 assert.equal((await publicList()).items.length,0,'an empty note cannot bypass displayed cafe text screening')
 const cafeItemJob=async()=>(await db.query("select * from private.screening_jobs where subject_kind='list_item' and subject_id=$1",[item])).rows[0]
 assert((await cafeItemJob()).payload.text.includes('Synthetic cafe'))
 await approve()
 const priorCafeRevision=(await cafeItemJob()).revision
 await db.query("update public.cafes set name='Corrected synthetic cafe',address='Shared cafe address' where id=$1",[cafe])
 assert.equal((await publicList()).items.length,0,'server catalog corrections invalidate admitted item metadata')
 assert.notEqual((await cafeItemJob()).revision,priorCafeRevision)
 assert((await cafeItemJob()).payload.text.includes('Shared cafe address'))
 const refreshedCafeText=(await cafeItemJob()).payload.text
 await db.query("select private.refresh_collection_screening_v1('list_item',$1)",[item])
 assert.equal((await cafeItemJob()).payload.text,refreshedCafeText,'refresh rebuilds without duplicate cafe text')
 await db.query("insert into public.profile_favorite_spots(user_id,position,descriptor,cafe_id) values($1,0,'Favorite descriptor',$2)",[owner,cafe])
 assert((await db.query("select payload->>'text' as text from private.screening_jobs where subject_kind='user' and subject_id=$1",[owner])).rows[0].text.includes('Corrected synthetic cafe'),'profile favorite names are included')
 const cafeVisit='20000000-0000-4000-8000-000000000099'
 await db.query("insert into public.visits(id,user_id,cafe_id,visibility,upload_state,caption,notes) values($1,$2,$3,'private','complete','PRIVATE CAFE CAPTION','PRIVATE CAFE NOTE')",[cafeVisit,owner,cafe])
 assert.equal((await db.query("select count(*)::int n from private.screening_jobs where subject_kind='visit' and subject_id=$1",[cafeVisit])).rows[0].n,0,'private cafe choice creates no screening payload')
 await db.query("update public.visits set visibility='everyone',caption='Shared cafe caption' where id=$1",[cafeVisit])
 const cafeVisitPayload=(await db.query("select payload from private.screening_jobs where subject_kind='visit' and subject_id=$1",[cafeVisit])).rows[0].payload
 assert(cafeVisitPayload.text.includes('Corrected synthetic cafe') && !cafeVisitPayload.text.includes('PRIVATE CAFE NOTE'))
 await db.query('delete from public.visits where id=$1',[cafeVisit])
 await db.query('delete from public.profile_favorite_spots where user_id=$1',[owner])
 await approve()
 const cafeRecommendation=(await db.query("insert into public.trusted_recommendations(id,sender_id,recipient_id,target_kind,target_cafe_id,status,note) values(gen_random_uuid(),$1,$2,'cafe',$3,'sent','Shared recommendation') returning id",[owner,friend,cafe])).rows[0].id
 const cafeRecommendationJob=async()=>(await db.query("select * from private.screening_jobs where subject_kind='recommendation' and subject_id=$1",[cafeRecommendation])).rows[0]
 assert((await cafeRecommendationJob()).payload.text.includes('Corrected synthetic cafe'))
 await approve()
 await db.query("update public.cafes set website_url='https://synthetic.invalid/shared-site' where id=$1",[cafe])
 assert.equal((await cafeRecommendationJob()).state,'pending','catalog correction invalidates direct cafe recommendation')
 await db.query('delete from public.trusted_recommendations where id=$1',[cafeRecommendation])
 await db.query("update public.cafe_lists set visibility='private' where id=$1",[list])
 assert.equal((await db.query("select count(*)::int as total from private.screening_jobs where subject_kind in ('list','list_item','list_comment')")).rows[0].total,0,'private list removes all nested payloads')
 assert.equal(await allowed('can_view_cafe_list_as',list,friend),false,'friendship alone does not expose a private list')
 await db.query("insert into public.cafe_list_members(list_id,user_id,role,invitation_status) values($1,$2,'viewer','pending')",[list,friend])
 assert.equal(await allowed('can_view_cafe_list_as',list,friend),true,'explicit invitation retains its private summary')
 assert.equal(await allowed('can_view_cafe_list_items_as',list,friend),false,'pending invitation cannot read private items')
 await db.query("update public.cafe_list_members set invitation_status='accepted' where list_id=$1 and user_id=$2",[list,friend])
 await db.query("update public.cafe_list_items set contributor_id=$1,note='Synthetic private collaborative note' where id=$2",[owner,item])
 assert.equal(await allowed('can_view_cafe_list_items_as',list,friend),true)
 await db.query("select set_config('test.actor',$1,false)",[friend])
 const privateList=(await db.query('select public.get_cafe_list_v2($1) as result',[list])).rows[0].result
 assert.equal(privateList.items[0].note,'Synthetic private collaborative note','accepted collaborator reads the owner note without AI screening')
 assert.equal((await db.query("select count(*)::int as total from private.screening_jobs where subject_kind in ('list','list_item','list_comment')")).rows[0].total,0)
 assert.equal(await allowed('is_public_cafe_list_as',list,null),false,'private collaboration never grants anonymous access')
 await db.exec("select set_config('test.blocked','true',false)")
 assert.equal(await allowed('can_view_cafe_list_items_as',list,friend),false,'blocks still cut off private collaboration')
 await db.exec("select set_config('test.blocked','false',false)")
 await db.query('delete from public.cafe_list_members where list_id=$1 and user_id=$2',[list,friend])
 assert.equal(await allowed('can_view_cafe_list_items_as',list,friend),false,'membership withdrawal removes private access')
 const recipe='80000000-0000-4000-8000-000000000001',version='90000000-0000-4000-8000-000000000001'
 await db.query("insert into public.recipe_identities values($1,$2,'Synthetic recipe')",[recipe,owner])
 await db.query("insert into public.recipe_versions(id,recipe_identity_id,version_number,version_label,brew_details,visibility) values($1,$2,1,'First',$3,'private')",[version,recipe,{beans:'Synthetic beans',private_notes:'PRIVATE RECIPE SENTINEL'}])
 assert.equal((await db.query("select count(*)::int as total from private.screening_jobs where subject_kind='recipe'")).rows[0].total,0)
 assert.equal(await allowed('can_project_recipe_version_as',version,friend),false,'friendship alone does not share a private recipe')
 assert.equal(await allowed('can_project_recipe_version_as',version,null),false,'anonymous access stays closed')
 const privateRecommendation=(await db.query("insert into public.trusted_recommendations(id,sender_id,recipient_id,target_kind,target_recipe_version_id,status,note) values(gen_random_uuid(),$1,$2,'recipe',$3,'sent','Synthetic private-recipe invitation') returning id",[owner,friend,version])).rows[0].id
 assert.equal(await allowed('can_project_recipe_version_as',version,friend),true,'explicit recipient can project the private recipe')
 assert.equal(await allowed('can_view_recipe_version_as',version,friend),true,'recipient retains version access')
 assert.equal(await allowed('can_view_recipe_identity_as',recipe,friend),true,'recipient retains identity access')
 assert.equal((await db.query("select count(*)::int total from private.screening_jobs where subject_kind='recipe'")).rows[0].total,0,'private recipe never goes to provider queue')
 await db.exec("select set_config('test.blocked','true',false)")
 assert.equal(await allowed('can_project_recipe_version_as',version,friend),false,'blocks revoke private projection')
 assert.equal(await allowed('can_view_recipe_version_as',version,friend),false,'blocks revoke private version access')
 await db.exec("select set_config('test.blocked','false',false)")
 await db.exec("select set_config('test.hidden','true',false)")
 assert.equal(await allowed('can_project_recipe_version_as',version,friend),false,'suspension revokes private projection')
 assert.equal(await allowed('can_view_recipe_version_as',version,friend),false,'suspension revokes raw recipe version access')
 assert.equal(await allowed('can_view_recipe_identity_as',recipe,friend),false,'suspension revokes raw recipe identity access')
 await db.exec("select set_config('test.hidden','false',false)")
 await db.query("update public.trusted_recommendations set status='dismissed' where id=$1",[privateRecommendation])
 assert.equal(await allowed('can_project_recipe_version_as',version,friend),false,'dismissal revokes private recipient access')
 await db.query('delete from public.trusted_recommendations where id=$1',[privateRecommendation])
 await db.query("update public.recipe_versions set visibility='friends' where id=$1",[version])
 assert.equal(await allowed('can_project_recipe_version_as',version,friend),false)
 const recipePayload=(await db.query("select payload from private.screening_jobs where subject_kind='recipe'")).rows[0].payload
 assert(!JSON.stringify(recipePayload).includes('PRIVATE RECIPE SENTINEL'),'only published recipe fields are screened')
 await approve()
 assert.equal(await allowed('can_project_recipe_version_as',version,friend),true)
 await db.query("update public.recipe_identities set name='Edited recipe' where id=$1",[recipe])
 assert.equal(await allowed('can_project_recipe_version_as',version,friend),false,'recipe name edits invalidate version approval')
 const detail={beans:'Synthetic beans',private_notes:'PRIVATE TOP SENTINEL',coffeeBag:{name:'Shared bean name',private_notes:'PRIVATE BAG SENTINEL'},equipmentSnapshots:[{role:'grinder',displayName:'Shared grinder',private_notes:'PRIVATE EQUIPMENT SENTINEL'}],steps:[{id:version,instruction:'Shared instruction',private_notes:'PRIVATE STEP SENTINEL'}]}
 await db.query('update public.recipe_versions set brew_details=$1 where id=$2',[detail,version])
 await approve()
 await db.query("select set_config('test.actor',$1,false)",[friend])
 const projectedRecipe=(await db.query('select public.get_recipe_projection_v1($1) as projection',[version])).rows[0].projection
 assert(projectedRecipe.brew_details.steps[0].instruction==='Shared instruction')
 assert(!JSON.stringify(projectedRecipe).includes('SENTINEL'),'nested private fields never enter outward recipe JSON')
 const screenedRecipe=(await db.query("select payload from private.screening_jobs where subject_kind='recipe'")).rows[0].payload
 assert(!JSON.stringify(screenedRecipe).includes('SENTINEL') && !JSON.stringify(screenedRecipe).includes(version),'screening drops private nested fields and internal step IDs')
 await db.query("insert into public.trusted_recommendations(id,sender_id,recipient_id,target_kind,target_recipe_version_id,status,note) values(gen_random_uuid(),$1,$2,'recipe',$3,'sent','Synthetic recommendation note')",[owner,friend,version])
 assert.equal((await db.query('select * from public.list_shared_recipes()')).rows.length,0,'pending recommendation note stays out of legacy recipe inbox')
 await approve()
 assert.equal((await db.query('select * from public.list_shared_recipes()')).rows.length,1)
 await db.query("update public.cafe_lists set visibility='public' where id=$1",[list])
 await db.query("update public.cafe_list_items set note='Unapproved source note' where id=$1",[item])
 await db.exec("update private.screening_jobs set state='approved' where subject_kind='list'")
 const copied=(await db.query('select public.copy_public_cafe_list_v1($1) as projection',[list])).rows[0].projection
 assert.equal(copied.items.length,0,'copy RPC cannot launder another author pending note into owner-only data')

 // Exercise the real protected-media migration with the screening helpers above.
 await db.exec("create table storage.buckets(id text primary key,public boolean); insert into storage.buckets values('profile-media',true),('visit-photos',true),('visit-photos-private',false)")
 await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260913061308_sprint1_protected_media_reads.sql',import.meta.url),'utf8'))
 assert.equal((await db.query('select count(*)::int as n from storage.buckets where public')).rows[0].n,0,'all user-media buckets become private')
 const mediaPath=`${owner}/${visit}/screened photo.jpg`
 const mediaURL=`mugshot-storage://visit-photos-private/${owner}/${visit}/screened%20photo.jpg`
 const avatarPath=`${owner}/avatar.jpg`
 const avatarURL=`https://project.supabase.co/storage/v1/object/public/profile-media/${avatarPath}`
 await db.query("insert into public.visits(id,user_id,caption,poster_photo_url,visibility,upload_state) values($1,$2,'Synthetic media check',$3,'everyone','complete')",[visit,owner,mediaURL])
 await db.query('update public.users set avatar_url=$1 where id=$2',[avatarURL,owner])
 for(const [bucket,name] of [['visit-photos-private',mediaPath],['visit-photos',mediaPath],['visit-photos-private',`${owner}/${visit}/unused.jpg`],['profile-media',avatarPath],['profile-media',`${owner}/old.jpg`]]) {
  await db.query('insert into storage.objects(id,bucket_id,name) values(gen_random_uuid(),$1,$2)',[bucket,name])
 }
 await db.exec('alter table storage.objects enable row level security; grant usage on schema storage to anon,authenticated; grant select on storage.objects to anon,authenticated; create policy synthetic_legacy_public_read on storage.objects for select to public using(true)')
 const mediaRead=async(actor,bucket,name)=>{
  await db.query("select set_config('test.actor',$1,false)",[actor??''])
  await db.exec(actor?'set role authenticated':'set role anon')
  try{return (await db.query('select count(*)::int as n from storage.objects where bucket_id=$1 and name=$2',[bucket,name])).rows[0].n===1}finally{await db.exec('reset role')}
 }
 assert.equal(await mediaRead(null,'visit-photos-private',mediaPath),false,'anonymous pending Everyone media denied despite old permissive policy')
 assert.equal(await mediaRead(owner,'visit-photos-private',mediaPath),true,'owner retains pending upload access')
 await approve()
 assert.equal(await mediaRead(null,'visit-photos-private',mediaPath),true,'approved Everyone exact object is readable')
 assert.equal(await mediaRead(null,'visit-photos',mediaPath),false,'same path in wrong bucket is not screened media')
 assert.equal(await mediaRead(friend,'visit-photos-private',`${owner}/${visit}/unused.jpg`),false,'unreferenced files are not part of an approved visit')
 assert.equal(await mediaRead(null,'profile-media',avatarPath),true,'current screened avatar is readable')
 assert.equal(await mediaRead(null,'profile-media',`${owner}/old.jpg`),false,'old avatar is not public')
 await db.query("update public.visits set visibility='friends' where id=$1",[visit]);await approve()
 assert.equal(await mediaRead(null,'visit-photos-private',mediaPath),false,'Friends media does not become anonymous through Storage')
 assert.equal(await mediaRead(friend,'visit-photos-private',mediaPath),true,'confirmed friend remains authorized')
 await db.exec("select set_config('test.blocked','true',false)")
 assert.equal(await mediaRead(friend,'visit-photos-private',mediaPath),false,'block revokes future signing')
 assert.equal(await mediaRead(friend,'profile-media',avatarPath),false,'block also protects profile media')
 await db.exec("select set_config('test.blocked','false',false)")
 await db.query("update public.visits set visibility='private' where id=$1",[visit])
 assert.equal(await mediaRead(friend,'visit-photos-private',mediaPath),false,'Private media stays owner-only')
 assert.equal(await mediaRead(owner,'profile-media',`${owner}/old.jpg`),true,'owner can clean up old media')
 console.log('PASS protected Storage buckets, actual RLS, screening, exact reference/bucket membership, Friends/Private audiences, blocks and owner recovery')
 console.log('PASS primary and collection screening: revision triggers, owner access, public/legacy projections, private fields, media edits, consent, blocks and withdrawal')
} catch(error) { console.error(error.message); process.exitCode=1; } finally {await db.close()}
