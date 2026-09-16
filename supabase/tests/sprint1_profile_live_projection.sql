begin;
update public.users set website_url='https://example.invalid/synthetic-website'
where id='00000000-0000-4000-8000-000000000102';
do $$ begin
 if not exists(select 1 from private.screening_jobs where subject_kind='user'
 and subject_id='00000000-0000-4000-8000-000000000102' and state='approved'
 and reason='local_text_filter'
 and payload->>'text' like '%https://example.invalid/synthetic-website%') then
 raise exception 'website missing from profile screening';end if;
end $$;
set local role anon;
do $$ begin
 if public.get_profile_link_v1('@alpha_fixture_2') is null then raise exception 'locally admitted website unavailable';end if;
end $$;
reset role;
update private.screening_jobs set state='rejected',reason='human_review'
where subject_kind='user' and subject_id='00000000-0000-4000-8000-000000000102';
set local role anon;
do $$ begin
 if public.get_profile_link_v1('@alpha_fixture_2') is not null then raise exception 'rejected website exposed';end if;
end $$;
reset role;
update private.screening_jobs set state='approved',reason='human_review'
where subject_kind='user' and subject_id='00000000-0000-4000-8000-000000000102';
set local role anon;
do $$ declare profile jsonb;begin
 profile:=public.get_profile_link_v1('@alpha_fixture_2');
 if profile is null or profile->'profile'->>'username' is distinct from 'alpha_fixture_2'
 or profile->'profile'->>'website_url' is distinct from 'https://example.invalid/synthetic-website' then
 raise exception 'admitted profile projection is missing required fields';end if;
 perform * from public.list_profile_link_sips_v1('@alpha_fixture_2');
end $$;
reset role;
rollback;
