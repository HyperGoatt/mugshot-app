# Public cafe list landing

This public Edge Function renders only `get_public_cafe_list_v1` output.
Configure the production reverse proxy so `/l/{opaqueSlug}` reaches this
function while preserving the canonical URL. Serve the shared
`apple-app-site-association` file without redirects at
`https://mugshotapp.co/.well-known/apple-app-site-association`.

Required runtime variables:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEYS` (preferred named JSON map), `SUPABASE_ANON_KEY`,
  or `SUPABASE_PUBLISHABLE_KEY`
- `MUGSHOT_MARKETING_URL=https://mugshotapp.co` (optional default)
- `MUGSHOT_DOWNLOAD_URL=https://mugshotapp.co/download?placement=share`
  (optional default)

Missing, private, deleted, moderated, revoked, and malformed links all receive
the same neutral unavailable response.
