# Public cafe list landing

This public Edge Function renders only `get_public_cafe_list_v1` output.
Configure the production reverse proxy so `/l/{opaqueSlug}` reaches this
function while preserving the canonical URL. Serve the shared
`apple-app-site-association` file without redirects at
`https://mugshotapp.co/.well-known/apple-app-site-association`.

Required runtime variables:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` or `SUPABASE_PUBLISHABLE_KEY`
- `MUGSHOT_PWA_URL=https://mugshotapp.co/`
- `MUGSHOT_APP_STORE_URL` once the App Store destination exists

Missing, private, deleted, moderated, revoked, and malformed links all receive
the same neutral unavailable response.
