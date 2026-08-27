---
document_type: living
status: current
last_verified: 2026-08-26
---

# Mugshot change log

## 2026-08-26

- Distributed the completed remediation sprint as TestFlight 0.5.3 (6) from
  exact `main` commit `b498d92`. The candidate passed Simulator and Release
  archive gates; the owner reported completed device QA and explicitly waived
  a redundant connected-iPhone rerun after the final sync. Xcode uploaded the
  archive at 9:37 PM EDT, App Store Connect completed processing, and the build
  is `Testing` for Mugshot Team and Alpha Friends with the published note
  `Welcome to Mugshot!`. Replacement-build product acceptance and feedback
  resolution remain separate.
- Implemented the latest owner-QA Feed and Profile-share follow-up on
  `codex/testflight-feedback-remediation`. The Feed scope rail now rests
  directly beneath the compact subtitle instead of reserving a second
  16-point gutter, and the space from the rail to the first Mugshot card now
  matches the same compact eight-point rhythm above it. The zero-height refresh
  reader moved behind the scope reservation so it no longer contributes hidden
  stack spacing; Your Mix, Friends, and Everyone retain identical control
  geometry, refresh isolation, the 60-point stationary threshold, and the
  continuous slide beneath the header. Profile-share content is explicitly
  sorted newest-first and now retains durable private-Storage photo references
  long enough for the authenticated media service to resolve them before
  rendering. This makes the snapshot grid match the current public Profile
  instead of dropping recent Friends-profile media and falling through to old
  public HTTPS photos. Private Mugshots remain excluded by the profile
  publication contract. The app Debug build/install/launch, 30 focused profile
  and Feed-domain tests after one floating-point assertion correction, the
  corrected single Feed test, the final equal-gap Feed test, live Feed capture,
  live current-profile share render, and same-input comparison boards pass on
  the standard Simulator. A
  read-only production query confirmed that the server projection was already
  newest-first and that the omitted recent rows used durable Storage
  references; no production data or policy was mutated. Full-static passed its
  11 non-Xcode stages, skipped optional `pglast`, and reproduced the known
  Xcode 27 generic XCTest-framework Info.plist packaging failure; the normal
  XcodeBuildMCP app build and focused tests passed. This latest source has not
  been promoted to a connected iPhone or TestFlight.
- Implemented public Profile sharing on
  `codex/testflight-feedback-remediation`. The owner Profile menu now opens a
  dedicated Mugshot share hub instead of handing iOS a bare URL. It renders
  exact 1080×1920 Story and 1080×1350 Post snapshots from the recipient-visible
  profile projection, preserving the 112-point banner, foam-white statistics
  dock, public identity details, compact Favorite Spots, four-tab rail, and
  portrait Mugshot grid. The activity payload includes the selected artwork,
  concise `Add me on Mugshot — @handle` copy, and the canonical active profile
  URL with a branded link preview. Private Mugshots and private journal data
  never enter the share content model. Eight focused Editorial Atlas tests, a
  normal Simulator build/install/launch, full Story export inspection, and the
  owner native-share handoff pass. The export was corrected during acceptance
  so oversized profile content anchors at the hero instead of cropping away
  the banner and statistics dock. The exact source then built with the named
  development profile, installed, and launched successfully as
  `co.mugshot.app.dev` on Joe's connected iPhone. This is physical
  build/install/launch evidence only; hands-on Profile share acceptance remains
  with the owner and TestFlight remains untouched.
- Implemented the next Simulator-QA polish batch on
  `codex/testflight-feedback-remediation`. Profile exploration maps keep the
  existing Mugshot MapKit surface, pins, clustering, cafe count, and location
  control but no longer render the redundant owner-named ratings legend below
  the map. Feed gives every scope subtitle the same compact layout footprint,
  so choosing Your Mix no longer shifts the scope control; its two-line
  matching sentence uses the existing space with tighter line spacing.
  Structured comment mentions now route by the mentioned account record rather
  than reusing the post-tag lookup, so a mentioned-only person opens the
  existing profile and friendship flow. The fast no-Simulator gate, app Debug
  compile, and all 16 focused Sip Detail presentation tests pass. A normal
  Simulator build/install/launch then verified that Your Mix and Friends keep
  the scope control at the same vertical position with the full subtitle
  visible, Amanda's live profile map has no ratings box beneath it, and the
  live structured Amanda mention retains its mint/bold treatment. End-to-end
  mention-tap feel remains in the owner's active QA rather than being promoted
  as physical or TestFlight acceptance.
- Implemented the second Editorial Atlas physical-QA follow-up on
  `codex/testflight-feedback-remediation`. Friend profiles no longer render or
  request the low-value Taste overlap card, and sparse identity metadata,
  favorite drink, Instagram, and website details now share a compact wrapping
  rail instead of leaving a tall single-column gap. The Favorite Spot reason
  picker replaces its undiscoverable horizontal category scroller with a fully
  visible two-column grid for Drink, Vibe, Food, Occasion, Service, and Make it
  yours; accessibility sizes use one column, and Make it yours exposes the
  existing validated 30-character custom descriptor field immediately. The
  profile shell is now eager around its still-lazy media grids, and cafe card
  title geometry is stable, removing the nested-lazy content-height feedback
  loop that made the Cafes tab jitter instead of scrolling. Five focused
  profile tests, the normal Debug build/launch, the live Amanda profile, custom
  descriptor entry, and repeated scrolling through all 11 visible cafe cards
  passed on the standard iOS 27 Simulator. The full-static non-Xcode stages
  passed; its generic no-Simulator test packaging remains blocked by the known
  Xcode 27 XCTest-framework Info.plist harness issue, while the equivalent
  XcodeBuildMCP app build and focused tests pass. This repaired source has not
  yet been promoted back to a connected iPhone or TestFlight.
- Implemented the first Editorial Atlas physical-QA follow-up on
  `codex/testflight-feedback-remediation`. The shared profile returns to the
  112-point banner token while retaining its foam-white statistics dock,
  replaces image-heavy Favorite Spots with a compact descriptor/cafe text
  rail, and changes Add Favorite Spot to choose a Drink, Vibe, Food, Occasion,
  Service, or custom reason before choosing the cafe. Profile visibility is
  now explicit and owner-controlled: Friends Mugshots remain in Friends Feed
  but also appear on the public profile by default; an account setting can
  reduce the profile back to Everyone-only, and Private Mugshots remain absent
  from authored, cafe, map, and tagged profile projections in every state.
  Composer and Publish copy disclose that distinction. The sealed
  caller-bound Favorite Spots and profile-visibility contracts pass the focused
  PGlite ownership/privacy suite, including default/on/off behavior, anonymous
  profile links, canonical cafe stitching, tagged hides, and direct-table
  denial. The app build/launch, five focused Swift tests, rendered owner profile,
  and reason-first Add Favorite Spot journey pass on the standard iOS 27
  Simulator. Migration `20260826143102_profile_editorial_atlas.sql` is live in
  the connected Mugshot Supabase project; all expected tables/RPCs resolve, no
  advisor error was introduced, and existing cafe/sip/media rows were not
  rewritten. Physical acceptance of this follow-up and TestFlight acceptance
  remain separate owner-promoted gates.

## 2026-08-25

- Implemented the approved Editorial Atlas shared profile redesign on
  `codex/testflight-feedback-remediation`. Owner and friend profiles now share a
  photographic hero, foam-white tappable Friends/Sips/Cafes dock, streamlined
  identity and actions, up to three visual Favorite Spots, and four public tabs
  in the approved Mugshots, cafes, map, and tagged order. The map tab embeds the
  existing Mugshot MapKit surface, numeric pins, clustering, rating legend, and
  location control without dotted routes or a replacement map style. Mugshot
  and tagged grids retain 3:4 portrait crops; cafes use two-column visual cards.
  Owners can choose Favorite Spots from Mugshot/history or Apple Maps, assign a
  categorized or custom descriptor, reorder them, hide a tagged Mugshot from
  the profile, or remove their tag. The additive Supabase contract seals direct
  table access, exposes caller-bound mutations, groups cafes by canonical
  identity, restricts all public tabs/stats to Everyone content, keeps old v3
  profile/highlight clients compatible, and adds the new owner data to export.
  Profile Highlight is absent from the new UI. The profile-specific hermetic
  database contract, four focused Swift tests, full-static 12/0/1, all four
  deterministic Simulator tabs, and the final same-viewport visual comparison
  pass. The deterministic owner fixture also verifies profile actions, the
  Favorite Spots editor, tagged-grid controls, and the Hide from profile /
  Remove my tag sheet. A signed `iphoneos` Debug package builds and verifies locally.
  Per owner direction, physical-device testing is intentionally deferred until
  explicit promotion and is not a completion gate for this Simulator-scoped
  sprint. No migration was deployed.
- Implemented the second consolidated Simulator-QA follow-up on
  `codex/testflight-feedback-remediation`. The Feed scope pills now stay fixed
  during pull-to-refresh and the first 60 points of upward scrolling, then move
  continuously beneath the clipped Feed header over their measured height;
  this removes the abrupt lazy-stack disappearance while preserving Feed
  reselect-to-top. Log a Sip now offers 12–18 preparation-specific criteria
  across every parsed drink preparation and Home brew method, keeps the
  suggestion rail stationary above selected criteria, and preserves the
  existing score/importance contract. Central Add always creates a fresh blank
  draft, every composer step has a native X plus Back when applicable, and an
  explicit Resume draft action opens the only saved draft directly or presents
  a picker when several exist; Journal draft routes remain unchanged. Cafe
  detail now recognizes durable `mugshot-storage://` poster references as
  remote Storage media instead of sending them to the local cache. A read-only
  production aggregate confirmed Sightsee has two complete visits with poster
  references and ten photo rows; no records, Storage objects, or policies were
  mutated. Cafe identity now read-stitches same-name/same-address provider
  records across reversed address formats, optional ZIP codes, and guarded
  same-location fallbacks. Map pins, personal library projection, Cafe Details,
  and Map preview combine visits and poster media across every stitched remote
  cafe ID without rewriting production rows. A read-only production check
  confirmed the three Tiny Nook records at 267 Rutledge contain three complete
  sips and five photo rows together. All 28 earlier focused criteria,
  Feed-motion, draft-domain, and cafe-media tests passed; four additional Feed
  timing and cafe-stitch tests plus a normal Simulator build/install/launch
  passed. The preceding source also built with development signing, installed,
  and launched as `co.mugshot.app.dev` on Joe's connected iPhone. The latest
  Feed-motion source passed its focused test and fast static gate, then built
  installed, and launched on that iPhone after it was unlocked. This is
  physical app-launch evidence only; manual motion acceptance remains.
- Implemented the consolidated Simulator-QA follow-up on
  `codex/testflight-feedback-remediation`. Reselecting Feed now scrolls to the
  top; the Your Mix/Friends/Everyone control participates in feed scrolling so
  the fixed Feed header and actions remain compact after it leaves view.
  Journal hides its redundant toolbar profile action behind a disabled feature
  flag and routes Taste Passport to a Mugsy upgrade holding screen. Composer
  navigation now uses the single native toolbar control surface, drink-context
  suggestions exclude unrelated espresso or matcha criteria, and criterion
  importance persists by account and criterion scope without carrying visit
  scores forward. Publish preserves its accepted preview, caption position,
  and share flows while restoring the compact inline Audience, Raw note, and
  Tag people controls; private-note editing remains in the reflection flow.
  Cafe detail now renders every viewer-visible remote Mugshot returned by the
  existing RLS-scoped query before falling back to local history, and missing
  local media says `Photo unavailable` instead of `Legacy sip`. Seventeen
  focused composer/domain tests, the Feed reselect and Taste Passport UI
  journeys, full-static 12/0/1, and a normal Simulator build/install/launch
  passed. Manual Publish, criterion, close-control, and cafe-detail retesting
  remains part of the active Simulator walkthrough.

## 2026-08-24

- Implemented the revised 44-report TestFlight remediation candidate on
  `codex/testflight-feedback-remediation`: identifier-based tabs preserve the
  Map, Feed, Add, Saved, Journal order while signed-in launch defaults to Feed;
  Journal and Feed are more compact; Publish supports direct summary edits and
  recoverable photo deletion; comments retain one-level reply structure; and
  post likes now support Like, Love, Laugh, and Yummy through an additive,
  caller-bound Supabase contract. Share-card output now includes a safe
  city/state and `@handle` with corrected export bounds, while the approved
  share hub/sheet and Publish-preview geometry remain unchanged. Added a
  review-only code-native Mugsy vector PDF exporter, cafe address-order
  reconciliation, focused Swift tests, a hermetic post-reaction contract, and
  the privacy-safe 44-report ledger. Caption entry now occurs only on Publish,
  and closing a successful Add flow returns to the last non-Add tab with Feed
  fallback while an explicit Passport action still routes to Journal. Local
  acceptance passed 425 unit tests, eight focused UI journeys, visual review of
  all 43 screenshots plus the text-only report, and full-static 12/0/1. A
  signed Debug build and install passed on Joe's iPhone; runtime launch was
  denied because the phone was locked. Physical runtime, production reaction
  configuration, replacement TestFlight acceptance, and report resolution
  remain separate pending gates.
- Implemented TestFlight-feedback polish for Feed and Map on
  `codex/feed-map-launch-polish`. Feed now keeps the Your Mix subtitle to two
  lines and reduces the scope-control-to-first-post gap from 18 to 8 points.
  Map camera reconciliation now preserves a current-location request that
  arrives while its broad launch fallback is still settling, so authorized
  launches center without requiring the location button. Added focused camera
  arbitration coverage. Full-static passed 12/0/1; the focused tests compiled
  in the Simulator-hosted app test bundle and remain queued with signed-device
  launch acceptance for the next consolidated runtime pass. Updated Current
  product status and Current sprint. Published as PR #57.
- Accepted the first real signed-device sandbox background delivery from a
  normal second-account like: the minute worker completed one send on its first
  attempt, Activity showed the unread item, the authoritative unread count
  reached zero after opening it, and its in-app destination routed correctly.
  The Feed bell stayed at `1` until activation, so
  `codex/activity-unread-badge-sync` now makes Feed observe the shared Activity
  store directly. Full-static passed 12/0/1, the signed build/install/launch
  passed, and a second first-attempt sandbox send physically proved the
  authoritative count, Activity marker, and Feed bell all clear immediately
  without relaunch. Updated Current product status, Current sprint, Feature
  status matrix, Notification system, Product roadmap, and TestFlight handoff.
- Physically launched the signed sandbox Debug app and accepted notification
  permission through its just-in-time Activity education. The settings surface
  reported the iPhone registered, and a privacy-safe aggregate backend check
  confirmed one active sandbox installation with badge sync. Saving master
  push off removed the sealed registration; restoring it recreated the row
  with every category true. A terminated cold launch restored the account and
  refreshed registration. No token, account ID, content, deep link, or synthetic
  production Activity was used; real cross-account APNs delivery remains.
  Updated Current product status, Current sprint, Feature status matrix,
  Notification system, Product roadmap, and TestFlight handoff.
- Installed the active `Mugshot Debug Push Development` profile and added
  device-only manual Debug signing so physical builds select it without
  changing Simulator or extension signing. The connected-iPhone build passed
  with the expected development identity, named profile,
  `co.mugshot.app.dev`, `MUGSHOT_PUSH_SANDBOX`, and
  `aps-environment=development`; the app installed successfully. The first
  remote launch was denied because the phone was locked, so runtime notification
  acceptance remains pending. Updated Current product status, Current sprint,
  Feature status matrix, Notification system, Repository map, Product roadmap,
  and TestFlight handoff.
- Generated `Mugshot Debug Push Development` for `co.mugshot.app.dev` with the
  existing development certificate and registered iPhone. Apple reports the
  profile active through 2027-08-24 with App Groups, In-App Purchase, and Push
  Notifications. Browser file handoff did not persist the download, and
  Xcode's command-line automatic retrieval failed because no Apple account is
  configured locally; download, installation, and physical acceptance remain
  pending. Updated Current product status, Current sprint, Feature status
  matrix, Notification system, Product roadmap, and TestFlight handoff.
- Implemented the source-build-5 iOS notification lifecycle: typed sandbox and
  production APNs environments, development/production entitlements,
  capability-gated v3 badge registration, shared authorization with nearby
  reminders, account-bound foreground/tap refresh, authoritative icon badges,
  injectable system/backend interfaces, truthful availability copy, and
  privacy-safe lifecycle analytics. Added focused coordinator, badge, signal,
  environment, and analytics tests. Full-static passed 12/0/1 with only the
  optional `pglast` parser skipped; 34 focused Simulator-hosted tests and a
  Simulator build/install/launch with Activity-surface inspection passed. A
  connected-iPhone build verified the Debug bundle/entitlement/environment
  selection and then failed closed because the installed development profile
  lacked `aps-environment`. Push Notifications was then enabled for the Debug
  App ID without creating redundant SSL certificates; generation and
  installation of the replacement development profile remain pending, so
  physical delivery is not accepted.
  Updated Notification system, Current sprint, Current product status, Feature
  status matrix, Real data flow status, Repository map, Product roadmap,
  PostHog analytics plan, and TestFlight handoff. Published and merged the
  implementation as PR #50 (`0d1cf21`).
- Added backward-compatible v3 APNs device registration and final delivery
  revalidation, including opt-in authoritative unread badges while retaining
  both v2 RPCs and the existing route envelope. Updated Notification system,
  Current sprint, Current product status, Feature status matrix, Real data flow
  status, Repository map, Product roadmap, and Supabase release workflow.
- Added the fail-closed canonical one-minute Activity delivery schedule using
  Vault, `pg_cron`, and `pg_net`; source and disposable QA are verified and the
  live deployment workflow remains in progress.
- Codified `deliver-activity` as a service-key-authenticated Edge Function with
  platform JWT verification disabled in `supabase/config.toml`; the worker
  still performs its own constant-time `apikey` check and supports a dedicated
  cron credential separate from its internal admin key.
- Disposable QA exposed and closed an inherited anonymous `visits` write
  grant. The share-link contract now enforces the current viewer rule: Everyone
  links are anonymous-readable, while Friends links require an eligible
  signed-in viewer.
- Replayed all 125 migrations through head `20260824165630` on a data-less
  Supabase branch, passed all 54 remote SQL contracts, and proved the single
  minute worker reaches its authenticated fail-closed state without APNs
  secrets. Updated Notification system, Current sprint, Current product status,
  Feature status matrix, Real data flow status, Product roadmap, and Supabase
  release workflow.
- Added a one-time production schedule cutover guard after live inventory found
  69 stale pending delivery attempts and no Activity cron job. Attempts older
  than 15 minutes become cancelled without deleting or suppressing in-app
  Activity; fresh and processing work is preserved. Full-static passed 13/0/0
  across 184 SQL files, and the disposable branch reached migration 126 with
  all 54 remote contracts green.
- Released migrations `20260824162710` through `20260824171405` and worker
  version 6 to production. Local/live history aligned at 126 migrations; the
  v3 capability and grants are live; protected users, visits, Activity events,
  preferences, Home data, and Storage fingerprints were unchanged. Exactly one
  Vault-backed minute job returned protocol-v3 HTTP 200 with zero claims after
  the 69 stale attempts were expired. The disposable QA branch was deleted.
- Verified the notification backend branch with the backend gate (12 passed,
  zero failed) and full-static gate (13 passed, zero failed), including local
  parsing of all 183 SQL files.
- Implemented and locally verified the Home Workbench, recipe memory, structured
  brew projection, and associated social/product checkpoint upgrades on
  `codex/home-workbench-sprint`.
- Established the living documentation index, current notification runbook,
  active sprint ledger, documentation policy, and freshness verification.
- Reconciled current product, architecture, data-flow, roadmap, analytics,
  Supabase, verification, and TestFlight documents with source build 0.5.3 (5).
- Published and merged the documentation/Home Workbench baseline as PR #46;
  synchronized local and remote `main` at merge `f91e2a4`.

## 2026-08-09

- Configured the production APNs key, sandbox and production topics, and durable
  Activity delivery schedule. Apple accepted both provider/topic probes; real
  device delivery and tapped cold launch remained pending.

## Earlier history

Use dated audits, checkpoints, deployment gates, and Git history for earlier
evidence. Those records remain historical rather than being rewritten here.
