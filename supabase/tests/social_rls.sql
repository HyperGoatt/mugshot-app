begin;

create temp table social_test_ids as
select id, row_number() over (order by id) n
from (select id from public.users order by id limit 3) users;
grant all on social_test_ids to authenticated;

do $$ begin
  if (select count(*) from social_test_ids) < 3 then
    raise exception 'social RLS suite requires three existing testable users';
  end if;
end $$;

delete from public.user_blocks where blocker_id in (select id from social_test_ids) and blocked_id in (select id from social_test_ids);
delete from public.friends where user_id in (select id from social_test_ids) and friend_user_id in (select id from social_test_ids);
delete from public.friend_requests where from_user_id in (select id from social_test_ids) and to_user_id in (select id from social_test_ids);

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object('sub',(select id from social_test_ids where n=1),'role','authenticated')::text,true);

select public.send_friend_request((select id from social_test_ids where n=2));
select public.send_friend_request((select id from social_test_ids where n=2));

do $$ begin
  if (select count(*) from public.friend_requests where status='pending'
      and from_user_id in (select id from social_test_ids)
      and to_user_id in (select id from social_test_ids)) <> 1 then
    raise exception 'repeated request was not idempotent';
  end if;
  begin
    perform public.send_friend_request((select id from social_test_ids where n=1));
    raise exception 'self request unexpectedly succeeded';
  exception when sqlstate '22023' then null;
  end;
end $$;

select set_config('request.jwt.claims', jsonb_build_object('sub',(select id from social_test_ids where n=3),'role','authenticated')::text,true);
do $$ begin
  if exists(select 1 from public.friend_requests
      where from_user_id in (select id from social_test_ids)
        and to_user_id in (select id from social_test_ids)) then
    raise exception 'stranger could read another pair request';
  end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object('sub',(select id from social_test_ids where n=2),'role','authenticated')::text,true);
select public.respond_friend_request((select id from public.friend_requests where status='pending'
  and from_user_id in (select id from social_test_ids) and to_user_id in (select id from social_test_ids)),true);

do $$ begin
  if (select count(*) from public.friends where user_id in (select id from social_test_ids)
      and friend_user_id in (select id from social_test_ids)) <> 2 then
    raise exception 'acceptance did not create a mutual friendship';
  end if;
  begin
    perform public.respond_friend_request((select id from public.friend_requests where status='accepted'
      and from_user_id in (select id from social_test_ids) and to_user_id in (select id from social_test_ids)),true);
    raise exception 'repeated acceptance unexpectedly succeeded';
  exception when sqlstate '55000' then null;
  end;
end $$;

select public.block_user((select id from social_test_ids where n=1));
do $$ begin
  if exists(select 1 from public.users where id=(select id from social_test_ids where n=1)) then
    raise exception 'blocked profile remained visible to blocker';
  end if;
  if exists(select 1 from public.friends where user_id in (select id from social_test_ids)
      and friend_user_id in (select id from social_test_ids)) then
    raise exception 'blocking did not remove friendship';
  end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object('sub',(select id from social_test_ids where n=1),'role','authenticated')::text,true);
do $$ begin
  if exists(select 1 from public.users where id=(select id from social_test_ids where n=2)) then
    raise exception 'block did not create mutual invisibility';
  end if;
  begin
    perform public.send_friend_request((select id from social_test_ids where n=2));
    raise exception 'blocked interaction unexpectedly succeeded';
  exception when sqlstate '42501' then null;
  end;
end $$;

select set_config('request.jwt.claims', jsonb_build_object('sub',(select id from social_test_ids where n=2),'role','authenticated')::text,true);
select public.unblock_user((select id from social_test_ids where n=1));

select set_config('request.jwt.claims', jsonb_build_object('sub',(select id from social_test_ids where n=1),'role','authenticated')::text,true);
select public.send_friend_request((select id from social_test_ids where n=2));
select set_config('request.jwt.claims', jsonb_build_object('sub',(select id from social_test_ids where n=2),'role','authenticated')::text,true);
select public.send_friend_request((select id from social_test_ids where n=1));

do $$ begin
  if (select count(*) from public.friend_requests where status='pending'
      and from_user_id in (select id from social_test_ids)
      and to_user_id in (select id from social_test_ids)) <> 1 then
    raise exception 'reversed request created a duplicate';
  end if;
end $$;

select public.submit_report(
  'spam'::public.report_reason,
  'transactional RLS test',
  (select id from social_test_ids where n=3),null,null
);
do $$ begin
  if (select count(*) from public.reports where details='transactional RLS test') <> 1 then
    raise exception 'caller-bound report was not visible to its reporter';
  end if;
end $$;

do $$
declare v_visit uuid; v_root uuid; v_reply uuid;
begin
  select id into v_visit from public.visits where visibility='everyone' and upload_state='complete' limit 1;
  if v_visit is not null then
    select id into v_root from public.create_comment(v_visit,'RLS root comment',null,'{}'::uuid[]);
    select id into v_reply from public.create_comment(v_visit,'RLS reply',v_root,'{}'::uuid[]);
    begin
      perform public.create_comment(v_visit,'RLS nested reply',v_reply,'{}'::uuid[]);
      raise exception 'nested reply unexpectedly succeeded';
    exception when sqlstate '23514' then null;
    end;
    perform public.submit_report('other'::public.report_reason,'transactional comment report',null,null,v_root);
  end if;
end $$;

reset role;
rollback;

select 'phase1_social_rls_passed' as result;
