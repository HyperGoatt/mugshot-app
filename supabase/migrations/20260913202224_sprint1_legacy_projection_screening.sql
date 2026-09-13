-- Security-definer legacy projections must enforce the same current-revision
-- admission as their table policies and canonical replacements.
do $$
declare source text;
begin
 source:=pg_get_functiondef('public.get_visit_v3_reflection_v1(uuid)'::regprocedure);
 if strpos(source,'reflection.context_criteria,')=0
    or strpos(source,'where reflection.visit_id = p_visit_id')=0 then
   raise exception 'reflection projection source drift';
 end if;
 source:=replace(source,'reflection.context_criteria,',
   'case when actor = reflection.user_id then reflection.context_criteria else private.canonical_post_criteria_v1(reflection.context_criteria) end,');
 source:=replace(source,'where reflection.visit_id = p_visit_id',
   'where reflection.visit_id = p_visit_id and private.can_view_visit_as(p_visit_id,actor)');
 execute source;
 source:=pg_get_functiondef('public.list_visit_comments_v2(uuid)'::regprocedure);
 if strpos(source,'where comment.visit_id = p_visit_id')=0
    or strpos(source,'where reply.parent_comment_id = comment.id')=0 then
   raise exception 'comment projection source drift';
 end if;
 source:=replace(source,'where comment.visit_id = p_visit_id',
   'where comment.visit_id = p_visit_id and (comment.user_id = viewer or private.screening_approved_v1(''comment'',comment.id))');
 source:=replace(source,'where reply.parent_comment_id = comment.id',
   'where reply.parent_comment_id = comment.id and (reply.user_id = viewer or private.screening_approved_v1(''comment'',reply.id))');
 execute source;
end;
$$;
