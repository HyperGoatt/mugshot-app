-- PostgREST runs the pre-request hook for server workers too. This grants
-- permission to execute the existing check; it does not bypass user sessions.
grant execute on function public.enforce_mugshot_live_session_v3() to service_role;
