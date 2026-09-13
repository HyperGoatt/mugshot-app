begin;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000101';
set local role authenticated;
insert into public.cafes(id,name,address) values('00000000-0000-4000-8000-000000009901','Private synthetic cafe','Private synthetic address');
do $$ begin
 if not exists(select 1 from public.cafes where id='00000000-0000-4000-8000-000000009901') then raise exception 'submitter lost cafe';end if;
 if has_function_privilege('authenticated','public.accept_verified_cafe_v1(uuid,text,text,jsonb)','execute')
 or has_function_privilege('anon','public.reserve_cafe_verification_v1(uuid)','execute') then raise exception 'client verifier access';end if;
end $$;
reset role;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000102';
set local role authenticated;
do $$ begin
 if exists(select 1 from public.cafes where id='00000000-0000-4000-8000-000000009901') then raise exception 'unverified cafe leaked';end if;
 begin
  insert into public.user_cafe_states(user_id,cafe_id,is_favorite) values(auth.uid(),'00000000-0000-4000-8000-000000009901',true);
  raise exception 'guessed cafe reference admitted';
 exception when insufficient_privilege then null;end;
 if exists(select 1 from public.resolve_cafe_summary('Private synthetic cafe')) then raise exception 'legacy resolver bypass';end if;
end $$;
-- Identically named manual cafes remain independently saveable without leaking.
insert into public.cafes(id,name,address) values('00000000-0000-4000-8000-000000009902','Private synthetic cafe','Private synthetic address');
reset role;
set local request.jwt.claim.sub='';
set local role anon;
do $$ begin
 if exists(select 1 from public.cafes where id in ('00000000-0000-4000-8000-000000009901','00000000-0000-4000-8000-000000009902')) then raise exception 'anonymous unverified cafe leak';end if;
end $$;
reset role;
set local role service_role;
do $$ declare result jsonb; again jsonb; n integer;
begin
 result:=public.accept_verified_cafe_v1('00000000-0000-4000-8000-000000000101','apple','ISYNTHETIC9901',
 '{"name":"Verified synthetic cafe","address":"123 Test St","city":null,"country":null,"latitude":1,"longitude":2}');
 again:=public.accept_verified_cafe_v1('00000000-0000-4000-8000-000000000101','apple','ISYNTHETIC9901',
 '{"name":"Verified synthetic cafe","address":"123 Test St","city":null,"country":null,"latitude":1,"longitude":2}');
 if result->>'id' is distinct from again->>'id' then raise exception 'verification retry duplicated cafe';end if;
 for n in 1..30 loop
 if not public.reserve_cafe_verification_v1('00000000-0000-4000-8000-000000000101') then raise exception 'early rate limit';end if;
 end loop;
 if public.reserve_cafe_verification_v1('00000000-0000-4000-8000-000000000101') then raise exception 'rate limit bypass';end if;
 if public.reserve_cafe_verification_v1('00000000-0000-4000-8000-000000009999') then raise exception 'unknown actor allowed';end if;
end $$;
reset role;
set local role anon;
do $$ begin
 if not exists(select 1 from public.cafes where apple_maps_place_id='ISYNTHETIC9901') then raise exception 'verified cafe unavailable';end if;
end $$;
reset role;
update public.cafes set name='Changed after verification' where apple_maps_place_id='ISYNTHETIC9901';
set local role anon;
do $$ begin
 if exists(select 1 from public.cafes where apple_maps_place_id='ISYNTHETIC9901') then raise exception 'stale provider attestation';end if;
end $$;
reset role;
rollback;
