begin;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000101';
set local role authenticated;
insert into public.cafes(id,name,address,latitude,longitude)
values('00000000-0000-4000-8000-000000009921','Saved access synthetic cafe','QA only',1,2);
insert into public.user_cafe_states(user_id,cafe_id,want_to_try)
values(auth.uid(),'00000000-0000-4000-8000-000000009921',true);
update public.user_cafe_states set is_favorite=true
where cafe_id='00000000-0000-4000-8000-000000009921';
do $$ begin
 if not exists(select 1 from public.user_cafe_states
 where cafe_id='00000000-0000-4000-8000-000000009921' and is_favorite and want_to_try)
 then raise exception 'owner Saved roundtrip failed'; end if;
 begin
  update public.user_cafe_states set user_id='00000000-0000-4000-8000-000000000102'
  where cafe_id='00000000-0000-4000-8000-000000009921';
  raise exception 'owner could transfer Saved row';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000102';
set local role authenticated;
do $$ begin
 if exists(select 1 from public.user_cafe_states
 where cafe_id='00000000-0000-4000-8000-000000009921')
 then raise exception 'other user could read Saved row'; end if;
 update public.user_cafe_states set is_favorite=false
 where cafe_id='00000000-0000-4000-8000-000000009921';
 if found then raise exception 'other user could update Saved row'; end if;
 delete from public.user_cafe_states where cafe_id='00000000-0000-4000-8000-000000009921';
 if found then raise exception 'other user could delete Saved row'; end if;
end $$;
reset role;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000101';
set local role authenticated;
do $$ begin
 delete from public.user_cafe_states where cafe_id='00000000-0000-4000-8000-000000009921';
 if not found then raise exception 'owner could not remove Saved row'; end if;
 if has_table_privilege('anon','public.user_cafe_states','select') then
 raise exception 'anonymous Saved access'; end if;
end $$;
reset role;
rollback;
