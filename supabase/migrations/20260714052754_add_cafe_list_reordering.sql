create or replace function public.move_cafe_list_item(p_item_id uuid, p_position integer)
returns public.cafe_list_items
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  target public.cafe_list_items;
  old_position integer;
  new_position integer;
  last_position integer;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  select * into target from public.cafe_list_items where id = p_item_id for update;
  if not found or not private.can_edit_cafe_list_as(target.list_id, actor) then
    raise exception 'list unavailable' using errcode = '42501';
  end if;
  perform 1 from public.cafe_list_items where list_id = target.list_id for update;
  select greatest(count(*) - 1, 0) into last_position
    from public.cafe_list_items where list_id = target.list_id;
  old_position := target.position;
  new_position := greatest(0, least(coalesce(p_position, old_position), last_position));

  if new_position < old_position then
    update public.cafe_list_items set position = position + 1
      where list_id = target.list_id and id <> target.id
        and position >= new_position and position < old_position;
  elsif new_position > old_position then
    update public.cafe_list_items set position = position - 1
      where list_id = target.list_id and id <> target.id
        and position > old_position and position <= new_position;
  end if;
  update public.cafe_list_items set position = new_position where id = target.id returning * into target;
  update public.cafe_lists set updated_at = now() where id = target.list_id;
  return target;
end; $$;

revoke all on function public.move_cafe_list_item(uuid,integer) from public, anon;
grant execute on function public.move_cafe_list_item(uuid,integer) to authenticated;
;
