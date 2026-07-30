# Shared Mugshot landing

This public Edge Function renders only `get_public_mugshot_share_v1` output.
Configure the production reverse proxy so `/m/{opaqueSlug}` reaches this
function while preserving the canonical URL, then serve the same domain in the
Associated Domains `apple-app-site-association` file.

Required runtime variables:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` or `SUPABASE_PUBLISHABLE_KEY`
- `MUGSHOT_PWA_URL=https://mugshotapp.co/` before App Store launch
- `MUGSHOT_APP_STORE_URL` once the App Store destination exists; it takes
  precedence over the PWA destination

The function deliberately returns the same neutral unavailable state for
missing, private, deleted, moderated, revoked, and malformed links.

Serve the adjacent `apple-app-site-association` file without redirects from:

`https://mugshotapp.co/.well-known/apple-app-site-association`
