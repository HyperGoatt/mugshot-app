import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import {PGlite} from '@electric-sql/pglite'
const db=new PGlite()
const owner='10000000-0000-4000-8000-000000000001',other='10000000-0000-4000-8000-000000000002'
try {
 await db.exec(`create role anon;create role authenticated;create role service_role;create schema private;create schema auth;
 create table public.users(id uuid primary key);insert into public.users values('${owner}'),('${other}');
 create table private.moderation_operators(user_id uuid,is_active boolean,role text);
 create function auth.uid() returns uuid language sql stable as $$select null::uuid$$;
 create function private.is_live_account_as(id uuid) returns boolean language sql stable as $$select true$$;`)
 for(const name of ['20260913025947_sprint1_screening_queue','20260913045917_sprint1_screening_rate_limits']) await db.exec(await fs.readFile(new URL(`../../supabase/migrations/${name}.sql`,import.meta.url),'utf8'))
 const add=async(who,n)=>{for(let i=0;i<n;i++)await db.query("select private.enqueue_screening_v1('visit',gen_random_uuid(),$1,$2)",[who,{text:'Synthetic',images:[]}])}
 const claim=async(n=5)=>(await db.query('select * from public.claim_screening_jobs_v1($1)',[n])).rows
 const clear=()=>db.exec("update private.screening_jobs set state='approved',lease_token=null,lease_until=null where lease_token is not null")
 await add(owner,14);await add(other,3)
 let jobs=await claim()
 assert.equal(jobs.filter(x=>x.owner_id===owner).length,2,'owner concurrency is bounded')
 assert.equal(jobs.filter(x=>x.owner_id===other).length,2,'other owner still receives capacity')
 assert.equal((await claim()).length,0,'active owner leases prevent duplicate capacity')
 for(const id of ['10000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000005']) {
  await db.query('insert into public.users values($1)',[id]);await add(id,1)
 }
 assert.equal((await claim()).length,2,'global concurrent lease cap is six')
 assert.equal((await claim()).length,0,'overlapping dispatch cannot exceed global concurrency')
 await clear()
 // Reserve the last allowance for the first owner; its excess remains queued.
 await db.query('update private.screening_owner_budget set claimed=9 where owner_id=$1',[owner])
 jobs=await claim()
 assert.equal(jobs.filter(x=>x.owner_id===owner).length,1)
 await clear()
 assert.equal((await claim()).filter(x=>x.owner_id===owner).length,0,'minute owner limit enforced')
 assert.ok((await db.query("select count(*)::int n from private.screening_jobs where owner_id=$1 and state='pending' and attempts=0",[owner])).rows[0].n>0,'throttling spends no job attempts')
 await db.exec("update private.screening_dispatch_budget set claimed=60")
 await add(other,1)
 assert.equal((await claim()).length,0,'global minute budget enforced')
 await db.exec("update private.screening_dispatch_budget set window_start=now()-interval '2 minutes'; update private.screening_owner_budget set window_start=now()-interval '2 minutes'")
 assert.ok((await claim()).length>0,'new window resumes pending work')
 await db.query('delete from public.users where id=$1',[owner])
 assert.equal((await db.query('select count(*)::int n from private.screening_owner_budget where owner_id=$1',[owner])).rows[0].n,0,'account deletion erases owner budget')
 for(const role of ['anon','authenticated']) assert.equal((await db.query("select has_table_privilege($1,'private.screening_owner_budget','select') allowed",[role])).rows[0].allowed,false)
 console.log('PASS screening dispatch limits: owner fairness, concurrency, minute budgets, non-consuming holds, window reset and deletion')
}catch(error){console.error(error.message);process.exitCode=1}finally{await db.close()}
