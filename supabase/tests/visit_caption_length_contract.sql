begin;

create temp table visit_caption_test_user as
select id as user_id
from public.users
order by created_at
limit 1;

do $$ begin
  if not exists (select 1 from visit_caption_test_user) then
    raise exception 'visit caption contract requires one existing user';
  end if;

  -- Existing rows remain readable after the constraint is installed.
  perform count(*) from public.visits where caption is not null;
end $$;

create temp table visit_caption_test_visit (visit_id uuid not null);

with inserted as (
  insert into public.visits (
    id,
    user_id,
    drink_type,
    drink_subtype,
    caption,
    visibility,
    upload_state,
    ratings,
    overall_score,
    context_type,
    location_name,
    brew_details
  ) values (
    gen_random_uuid(),
    (select user_id from visit_caption_test_user),
    'Coffee',
    'Caption contract sip',
    repeat('a', 1000),
    'private',
    'complete',
    '{"Overall":4}'::jsonb,
    4,
    'home',
    'Home',
    '{}'::jsonb
  )
  returning id
)
insert into visit_caption_test_visit
select id from inserted;

update public.visits
set caption = repeat('☕', 1000)
where id = (select visit_id from visit_caption_test_visit);

do $$ begin
  if (
    select char_length(caption)
    from public.visits
    where id = (select visit_id from visit_caption_test_visit)
  ) <> 1000 then
    raise exception '1000-character Unicode caption was not stored intact';
  end if;

  begin
    insert into public.visits (
      id,
      user_id,
      drink_type,
      drink_subtype,
      caption,
      visibility,
      upload_state,
      ratings,
      overall_score,
      context_type,
      location_name,
      brew_details
    ) values (
      gen_random_uuid(),
      (select user_id from visit_caption_test_user),
      'Coffee',
      'Over-limit insert',
      repeat('a', 1001),
      'private',
      'complete',
      '{"Overall":4}'::jsonb,
      4,
      'home',
      'Home',
      '{}'::jsonb
    );
    raise exception '1001-character insert unexpectedly succeeded';
  exception
    when check_violation then null;
  end;

  begin
    update public.visits
    set caption = repeat('☕', 1001)
    where id = (select visit_id from visit_caption_test_visit);
    raise exception '1001-character update unexpectedly succeeded';
  exception
    when check_violation then null;
  end;
end $$;

rollback;

select 'visit_caption_length_contract_passed' as result;
