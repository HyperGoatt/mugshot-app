import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import pg from 'pg';

export function branchConfiguration(branchID, expectedRef) {
  if (!branchID || !/^[a-z]{20}$/.test(expectedRef ?? '') || expectedRef === 'quskamnfwglctqewwfln') throw new Error('Explicit isolated branch required');
  const config = JSON.parse(execFileSync('npx', ['--yes','supabase@2.109.1','branches','get',branchID,'--output','json'], {encoding:'utf8'}));
  if (new URL(config.SUPABASE_URL).hostname !== `${expectedRef}.supabase.co`) throw new Error('API branch mismatch');
  const sqlURL = new URL(config.POSTGRES_URL);
  if (!sqlURL.hostname.endsWith('.pooler.supabase.com') || sqlURL.username !== `postgres.${expectedRef}`) throw new Error('SQL branch mismatch');
  sqlURL.port = '5432';
  return {...config, sqlURL: sqlURL.href};
}

export async function fixture(config) {
  const db = new pg.Client({connectionString:config.sqlURL,ssl:{rejectUnauthorized:false},connectionTimeoutMillis:20000,application_name:'mugshot_home_acceptance'});
  await db.connect();
  console.log('Connected to isolated QA database');
  if ((await db.query('select count(*)::int n from cron.job where active')).rows[0].n !== 0) throw new Error('Disable QA schedules first');
  const api = async (route, token, body, method = 'POST', extra = {}) => {
    const response = await fetch(`${config.SUPABASE_URL}${route}`, {method,signal:AbortSignal.timeout(20000),headers:{
      apikey:config.SUPABASE_ANON_KEY,Authorization:`Bearer ${token ?? config.SUPABASE_ANON_KEY}`,
      'Content-Type':'application/json',...extra},body:body === undefined ? undefined : JSON.stringify(body)});
    const text = await response.text();
    let data; try {data=JSON.parse(text);} catch {data=text;}
    return {status:response.status,ok:response.ok,data};
  };
  const users=[];
  for (let i=0;i<3;i++) {
    const suffix=randomUUID().slice(0,8), email=`home-${suffix}@example.invalid`, password=randomUUID()+randomUUID();
    const created=await api('/auth/v1/admin/users',config.SUPABASE_SERVICE_ROLE_KEY,
      {email,password,email_confirm:true,user_metadata:{displayName:`Home QA ${i}`,username:`homeqa_${suffix}`}});
    if (!created.ok) throw new Error(`QA user creation failed (${created.status}): ${JSON.stringify(created.data)}`);
    const login=await api('/auth/v1/token?grant_type=password',null,{email,password});
    if (!login.ok) throw new Error(`QA login failed (${login.status})`);
    users.push({id:created.data.id,email,password,token:login.data.access_token});
    console.log(`Authenticated QA actor ${i+1}`);
  }
  return {db,api,users,config,rpc: (name,user,args) => api(`/rest/v1/rpc/${name}`,user?.token,args)};
}
