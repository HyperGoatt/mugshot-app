# Shared Mugshot metadata and routing

This public Edge Function resolves only `get_public_mugshot_share_v1` output.
The opaque slug is a revocable capability: an owner may share a complete
`Everyone` or `Friends` post, while `Private` posts never qualify.
Configure the production reverse proxy so `/m/{opaqueSlug}` reaches this
function while preserving the canonical URL, then serve the same domain in the
Associated Domains `apple-app-site-association` file.

Human browsers receive a redirect to the PWA's canonical `/m/{slug}` route,
which renders the real `VisitDetail` component. Link preview crawlers receive a
metadata-only document after the capability projection succeeds; no separate
human-facing post UI is served here. Private-bucket media is signed server-side
for five minutes. `?format=json` remains available to established clients and
`?format=og` returns the branded 1200×630 PNG used by Messages and social link
previews.

Required runtime variables:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEYS` (preferred named JSON map), `SUPABASE_ANON_KEY`,
  or `SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_SECRET_KEYS` (preferred named JSON map),
  `SUPABASE_SERVICE_ROLE_KEY`, or `SUPABASE_SECRET_KEY` for capability-bound
  private media signing
- `MUGSHOT_MARKETING_URL=https://mugshotapp.co` (optional default)
- `MUGSHOT_WEB_APP_URL=https://app.mugshotapp.co` (optional default)
- `MUGSHOT_DOWNLOAD_URL=https://mugshotapp.co/download?placement=share`
  (optional default)

The function deliberately returns the same neutral unavailable state for
missing, private, deleted, moderated, revoked, and malformed links. Successful
capability responses use `Cache-Control: private, no-store`; signed media URLs
expire after five minutes.

Serve the adjacent `apple-app-site-association` file without redirects from:

`https://mugshotapp.co/.well-known/apple-app-site-association`
