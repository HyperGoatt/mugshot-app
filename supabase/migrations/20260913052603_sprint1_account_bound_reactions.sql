create function public.set_visit_reaction_v2(p_visit_id uuid,p_actor uuid,p_reaction_kind text default null)
returns table(viewer_reaction text,like_count bigint,love_count bigint,laugh_count bigint,yummy_count bigint,total_count bigint)
language plpgsql security definer set search_path='' as $$
begin
  if p_actor is null or auth.uid() is distinct from p_actor then
    raise exception 'reaction account changed' using errcode='42501';
  end if;
  return query select * from public.set_visit_reaction_v1(p_visit_id,p_reaction_kind);
end;
$$;
revoke all on function public.set_visit_reaction_v2(uuid,uuid,text) from public,anon;
grant execute on function public.set_visit_reaction_v2(uuid,uuid,text) to authenticated;
