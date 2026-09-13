-- Shared catalog corrections are a server operation. Native and PWA clients
-- resolve or insert provider records; they do not edit the shared catalog.
drop policy if exists "Authenticated users can update cafes" on public.cafes;
revoke update on public.cafes from public,anon,authenticated;
