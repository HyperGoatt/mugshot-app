# Shared profile metadata and routing

This public Edge Function resolves the opaque `get_profile_share_v1` capability.
Human browsers redirect to the PWA's real `/p/{slug}` profile route. Link preview
crawlers receive metadata only; this function never renders a separate profile
screen. Revoked or invalid links return the same neutral unavailable response.

Configure the production reverse proxy so `/p/{opaqueSlug}` reaches this
function while preserving the canonical `https://mugshotapp.co/p/{slug}` URL.
The shared Associated Domains file already includes `/p/*`.

Runtime variables match `shared-mugshot`: `SUPABASE_URL`, a public Supabase key,
an optional secret Supabase key for capability-bound media signing,
`MUGSHOT_MARKETING_URL`, and `MUGSHOT_WEB_APP_URL`.
