# Shared Mugshot landing

This public Edge Function renders only `get_public_mugshot_share_v1` output.
Configure the production reverse proxy so `/m/{opaqueSlug}` reaches this
function while preserving the canonical URL, then serve the same domain in the
Associated Domains `apple-app-site-association` file.

Required runtime variables:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEYS` (preferred named JSON map), `SUPABASE_ANON_KEY`,
  or `SUPABASE_PUBLISHABLE_KEY`
- `MUGSHOT_MARKETING_URL=https://mugshotapp.co` (optional default)
- `MUGSHOT_DOWNLOAD_URL=https://mugshotapp.co/download?placement=share`
  (optional default)

The function deliberately returns the same neutral unavailable state for
missing, private, deleted, moderated, revoked, and malformed links.

Serve the adjacent `apple-app-site-association` file without redirects from:

`https://mugshotapp.co/.well-known/apple-app-site-association`
