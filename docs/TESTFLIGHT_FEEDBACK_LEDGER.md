---
document_type: living
status: current
last_verified: 2026-08-26
---

# TestFlight feedback ledger

This is the privacy-safe disposition ledger for the 44 feedback packages
currently cached by Xcode Organizer. It excludes tester names, email addresses,
account identifiers, private content, and raw logs. Xcode evidence confirms that
the latest reports were submitted against 0.5.3 (5); older reports came from
0.5.3 (1), 0.5.2 (3), and 0.5.2 (2).

`Implemented` means source exists on `codex/testflight-feedback-remediation`.
`Local` is updated only after the named deterministic or runtime gate passes.
No Xcode report is resolved until the behavior is accepted in the replacement
TestFlight build.

Local acceptance passed with 425 unit tests, eight focused UI journeys, the
43-screenshot plus one-text-report review, and full-static 12/0/1; the single
skip is the optional local `pglast` parser. The initial signed 0.5.3 (5) Debug
launch was denied while Joe's iPhone was locked. The final current source later
built, installed, and launched successfully as `co.mugshot.app.dev` on that
connected iPhone. This is physical app-launch evidence only: report-level
physical acceptance remains Pending, production configuration is unchanged,
and every TestFlight report remains Open.

The 2026-08-25 Simulator walkthrough accepted the shell order/default,
Feed/profile/detail routing and layout, Journal hub and draft recovery, photo
deletion and cover repair, composer recovery, tagging, Map search, and nested
comments. That evidence is local Simulator acceptance only. Follow-up source
now adds Feed reselect-to-top, a scrolling scope control, a Taste Passport
upgrade holding screen, filtered criteria, persistent criterion importance,
compact Publish audience/note/tag controls, and viewer-visible cafe Mugshots;
17 focused composer/domain tests, the Feed reselect and Taste Passport UI
journeys, full-static 12/0/1, and a normal Simulator build/install/launch
passed. Manual Publish, criterion, close-control, and cafe-detail retesting
remains in the active walkthrough. A second QA source batch adds the
viewport-relative delayed Feed scope release, 12–18 stationary
preparation-specific criteria, fresh central Add with explicit one/multi-draft
recovery, an X on every composer step, and correct handling for private-Storage
cafe poster references. Its 28 focused tests and full-static 12/0/1 pass. A
third source batch shortened the Feed hold and conservatively stitched
provider-split cafe identities at read time so Map pins and details combine
RLS-visible visits/media across every equivalent ID. A fourth source batch now
keeps the scope pills fixed during refresh and the first 60 upward points, then
translates them continuously beneath the clipped header over their measured
height without a lazy-stack visibility jump. The latest focused Feed-motion
test and fast static gate pass. The prior five unique Feed/cafe tests, offline
verification 11/0/1, normal Simulator build/install/launch, and connected-iPhone
development build/install/launch also pass. The fourth source built and
installed on Joe's iPhone, then launched successfully after the device was
unlocked. Replacement-device motion and Tiny Nook acceptance remain, and no
report state is promoted by app-launch evidence alone.

The later approved Editorial Atlas profile redesign is implemented on the same
branch without changing any existing report's TestFlight state. Its first
physical-QA follow-up returns the banner to 112 points, keeps the foam-white
statistics dock, compacts Favorite Spots to descriptor/cafe text, and makes
Favorite Spot creation reason-first. Profile publication defaults to Friends
plus Everyone with an owner opt-out to Everyone-only; Private remains excluded
from every profile tab. The revised hermetic privacy contract, five focused
Swift tests, app build/launch, rendered owner profile, and reason-first
Simulator journey pass. Migration `20260826143102` is production-configured and
its expected tables/RPCs resolve. Any owner-promoted physical acceptance and
replacement-TestFlight acceptance remain separate gates.

The ensuing owner-promoted device walkthrough found a low-value Taste overlap
card, excess space on sparse friend profiles, hidden Favorite Spot categories
and custom entry behind a horizontal scroller, and a Cafes-tab scroll jitter.
The repaired source removes the card and its redundant compatibility request,
wraps sparse identity metadata into the available width, shows all six Favorite
Spot categories in a two-column grid with a direct custom field, and removes the
nested-lazy scroll-height feedback loop while retaining lazy media grids. Five
focused profile tests, a normal Debug build/launch, the live Amanda profile,
custom descriptor entry, and repeated scrolling through 11 cafe cards pass on
the standard iOS 27 Simulator. The repository full-static gate passed its 11
non-Xcode checks, retained the optional `pglast` skip, and hit the known Xcode 27
generic XCTest framework Info.plist packaging failure; the equivalent
XcodeBuildMCP app build and focused test run pass. This repaired source has not
yet been re-promoted to the connected iPhone, and no TestFlight report state is
changed.

The next QA polish batch removes the redundant owner-named ratings legend from
every profile map without changing the existing MapKit surface, gives all Feed
scope subtitles the same compact layout footprint so Your Mix does not shift
the scope control, and routes structured comment mentions through the mentioned
account metadata instead of the unrelated post-tag collection. The fast static
gate, all 16 focused Sip Detail presentation tests, normal Simulator
build/install/launch, live Your Mix/Friends geometry comparison, live Amanda
map, and live structured-mention render pass. Owner mention-tap feel, physical,
and TestFlight acceptance remain separate.

The subsequent owner-requested Profile share addition replaces the bare-URL
handoff with a dedicated share hub that renders fixed Story/Post snapshots from
the canonical link's public projection, then supplies the artwork, concise Add
me copy, and the active profile URL to the native share sheet. Private Mugshots
and journal-only fields are absent from the share content model. Eight focused
profile tests, a normal Simulator build/install/launch, full Story export
inspection, and the native share handoff pass. After explicit owner promotion,
the exact source also built, installed, and launched as `co.mugshot.app.dev` on
Joe's connected iPhone. This is physical app-launch evidence only and does not
change any of the original 44 reports' TestFlight acceptance states.

The latest owner-QA follow-up gives the Feed scope rail matching eight-point
gaps above and below it. The zero-height refresh reader no longer participates
in stack layout, while the three scope heights, refresh isolation, and approved
60-point release motion remain unchanged. It also corrects a client-only Profile-share
media divergence: the snapshot now sorts published Mugshots newest-first and
resolves durable private-Storage references before rendering, matching the live
Profile grid instead of skipping recent Friends-profile media and showing older
public HTTPS photos. The Debug Simulator build/launch, 30 focused tests with one
corrected floating-point assertion, green focused rerun, live Feed/share
captures, and same-input comparison boards pass. A production inspection was
read-only and confirmed the RPC was already newest-first; no data, Storage, or
policy mutation occurred. Full-static passed its 11 non-Xcode stages, skipped
optional `pglast`, and reproduced the known Xcode 27 generic XCTest-framework
Info.plist packaging failure; the equivalent XcodeBuildMCP app build and focused
tests passed. This source is not physically or TestFlight accepted.

## Workstreams

| Owner | Scope |
| --- | --- |
| R1 reliability / [PR #61](https://github.com/HyperGoatt/mugshot-app/pull/61) | Account/post deletion, canonical links, cafe identity, Map search, tagging, and profile routing |
| R2 shell / [PR #58](https://github.com/HyperGoatt/mugshot-app/pull/58) | Tabs, launch defaults, Journal, Feed, profiles, and shared shell polish |
| R3 composer / [PR #59](https://github.com/HyperGoatt/mugshot-app/pull/59) | Photos, criteria, reflection order, Publish review, and draft preservation |
| R4 social / [PR #62](https://github.com/HyperGoatt/mugshot-app/pull/62) | Threaded comments, mentions, expressive post reactions, activity, and legacy like compatibility |
| R5 output / [PR #60](https://github.com/HyperGoatt/mugshot-app/pull/60) | Share-output correctness and the review-only Mugsy vector handoff; share hub/sheet structure stays frozen |

## Reports

| # | Report ID | Origin | Feedback summary | Owner | Disposition | Implemented | Local | Physical | TestFlight |
| ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `ADgm-hymSiCLlxAmAqxbueM` | 0.5.3 (5), iPhone18,1, iOS 26.6 | Show `cafe \| city` only on one line; omit separator when wrapped | R2 | Accepted | Yes | Passed | Pending | Open |
| 2 | `AI7eKwAqaxAyl13z8c5Guu0` | 0.5.3 (5), iPhone18,1, iOS 26.6 | Reduce profile banner height | R2 | Accepted at 112 points | Yes | Passed | Pending | Open |
| 3 | `AMZeNgQANCObuq3wN5U97jE` | 0.5.3 (5), iPhone18,1, iOS 26.6 | Make Journal a clean compact profile/recent-sips hub | R2 | Accepted | Yes | Passed | Pending | Open |
| 4 | `AJaTPBVxKjaSSMH6LEHwuac` | 0.5.3 (5), iPhone18,1, iOS 26.6 | Consider swapping Journal and Map | R2 | Rejected by locked decision; identifier refactor only | Yes | Passed | Pending | Open |
| 5 | `AM2Gu7gEofxYarPCiyU1dkk` | 0.5.3 (5), iPhone18,1, iOS 26.6 | Export Mugsy as vector PDF or AI | R5 | PDF accepted; no AI or shipping-asset replacement | Yes | Passed | N/A | Open |
| 6 | `AOQFpW2F9cMtvE9zD9qr06o` | 0.5.3 (5), iPhone18,1, iOS 26.6 | Remove double-ring close control and launch signed-in users to Feed | R2/R3 | Accepted | Yes | Passed | Pending | Open |
| 7 | `AJ3QmQM05wzVWO8aORThJ4A` | 0.5.3 (5), iPhone17,1, iOS 27.0 | Nest replies immediately under their parent | R4 | Accepted, one level | Yes | Passed | Pending | Open |
| 8 | `AOWM6nQ9eORKKYT-DhAu0G0` | 0.5.3 (5), iPhone18,1, iOS 26.6 | Long-press heart for Like, Love, Laugh, and Yummy | R4 | Accepted | Yes | Passed | Pending | Open |
| 9 | `AGGLzpFUO2sU4nQKxZY4KMY` | 0.5.3 (5), iPhone18,1, iOS 26.6 | Remove highlighted post-detail whitespace | R2 | Accepted as secondary-content clamp/padding cleanup | Yes | Passed | Pending | Open |
| 10 | `AKAR-CG0cAdOkRcnj7qR6uk` | 0.5.3 (5), iPhone18,1, iOS 26.6 | Persist More/Most/Less importance | R3 | Accepted after Simulator QA: importance persists by account and criterion scope; visit scores remain fresh | Yes | Focused passed; manual UI pending | Pending | Open |
| 11 | `ADMa6OZntf6tstz1-bTojuQ` | 0.5.3 (5), iPhone18,1, iOS 26.6 | Edit every Publish summary without navigating back | R3 | Adjusted after Simulator QA: keep photos/identity/scores/caption edits; restore inline Audience, Raw note, and Tag people; edit private note by navigating back | Yes | Compiled; manual UI pending | Pending | Open |
| 12 | `AIPBqNqY8TO6z5hDLt0Zi6I` | 0.5.3 (5), iPhone18,1, iOS 26.6, text-only | Keep caption on Publish | R3 | Accepted | Yes | Passed | Pending | Open |
| 13 | `ADQ2JCLsXZ3-SXzNkhR1jNk` | 0.5.3 (5), iPhone17,1, iOS 27.0 | Reconcile duplicate cafe/address variants | R1 | Accepted; local and remote read projections stitch equivalent normalized addresses without mutating production rows | Yes | Focused passed; Tiny Nook UI pending | Pending | Open |
| 14 | `APsqFeV-H8n5DJE_hDMOSGQ` | 0.5.3 (5), iPhone17,1, iOS 27.0 | Mint/bold/tappable mentions and easy profile friendship flow | R4 | Existing safe mention/profile route retained and regression-gated | Yes | Passed | Pending | Open |
| 15 | `AGLtR9tJCEae5lcKioXCSC4` | 0.5.3 (5), iPhone18,1, iOS 26.6 | Show one completion check | R3 | Accepted | Yes | Passed | Pending | Open |
| 16 | `AOm82wNUbaXYRjqekmk2OTc` | 0.5.3 (5), iPhone18,1, iOS 26.6 | Add photo delete controls | R3 | Accepted with cover-index repair and recovery preservation | Yes | Passed | Pending | Open |
| 17 | `APKyVJqE6nd6S97369XMS-E` | 0.5.3 (1), iPhone18,1, iOS 26.6 | Anchor three-dot menu to the tapped control | R2 | Existing native Menu retained; regression-gated | Yes | Passed | Pending | Open |
| 18 | `ALei5_iEniQBpnAHFfcBS_A` | 0.5.3 (1), iPhone18,1, iOS 26.6 | Keep author at top and fit normal post in one viewport | R2 | Accepted | Yes | Passed | Pending | Open |
| 19 | `AH9G41dI5WrJzrE-JrYR1OU` | 0.5.3 (1), iPhone18,1, iOS 26.6 | Tap profile picture to open profile | R2 | Accepted | Yes | Passed | Pending | Open |
| 20 | `AEYaOkNyBuaV9mScP8z6gOg` | 0.5.3 (1), iPhone18,1, iOS 26.6 | Add city/location and `@handle` to share card | R5 | Accepted with safe allowlisted fields | Yes | Passed | Pending | Open |
| 21 | `ALGbZt-2cQnNGgF-84GPYdM` | 0.5.3 (1), iPhone18,1, iOS 26.6 | Simplify share hub actions | R5 | Rejected by locked decision; no structural change | Yes | Passed | Pending | Open |
| 22 | `AKCDqTH2rN4tXd_mPW3o0fk` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Correct share-card margins | R5 | Accepted as output-safe bounds only | Yes | Passed | Pending | Open |
| 23 | `AKzkEgAC1IqF6Q9XBXnf2F0` | 0.5.3 (1), iPhone17,1, iOS 27.0 | Shared post must open the canonical Mugshot | R1/R5 | Existing v2 canonical-link contract retained and regression-gated | Yes | Passed | Pending | Open |
| 24 | `ADCpi9hvDnvdlyNOCLbjZuI` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Correct share-card cropping | R5 | Accepted without changing format/layout/aspect | Yes | Passed | Pending | Open |
| 25 | `AIuEB9IfCr-b_j07OKT7MrM` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Show published receipt before customization | R5 | Existing accepted receipt retained | Yes | Passed | Pending | Open |
| 26 | `AAMmL_V14k58Nw9QseOwzqk` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Replace `5 of 5` with completion check | R3 | Accepted | Yes | Passed | Pending | Open |
| 27 | `AKIIFgPKxcKiYHskIsig7MY` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Make Publish preview square | R3 | Rejected by locked decision; ratio/cropping unchanged | Yes | Passed | Pending | Open |
| 28 | `AE5B_SBRpTildBuE8cX4gr4` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Fix wonky composer back/close controls | R3 | Accepted as one circular control surface | Yes | Passed | Pending | Open |
| 29 | `ALB1I2nz3ZLoNHaXBLmyDDg` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Put journal/caption after criteria reflection | R3 | Accepted; private note stays distinct from public caption | Yes | Passed | Pending | Open |
| 30 | `ALx7pcnwVDRVCednqgFlzW8` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Remove unnecessary share popup | R5 | Rejected by locked share-flow decision | Yes | Passed | Pending | Open |
| 31 | `AADqKta06Di9ykmXvUIALFg` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Smart Collage looks wrong | R5 | Frozen for separate redesign; functional regression gate only | Yes | Passed | Pending | Open |
| 32 | `AKlDAHPWMPiEg0FNQPbe95w` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Unknown people appear in tag suggestions | R1/R3 | Suggestions remain friend/prior-tag only; explicit search may find eligible accounts | Yes | Passed | Pending | Open |
| 33 | `AJlk-QIYZ4k7fnNLb-tZ-qI` | 0.5.2 (3), iPhone17,1, iOS 27.0 | Add Map search | R1 | Existing MapKit search retained and regression-gated | Yes | Passed | Pending | Open |
| 34 | `AOQC6L91oHBzUVFo1kstxbg` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Rename criterion to Body/Smoothness | R3 | Existing criterion rename retained; Publish exposes it directly | Yes | Passed | Pending | Open |
| 35 | `AMvtlq57gUkwBGqMY1U0gro` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Improve suggested criteria | R3 | Existing context-aware suggestions retained and exposed on Publish | Yes | Passed | Pending | Open |
| 36 | `APBNktky4OySmxcZqQIw4KQ` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Liquid Glass failure for tester | R2/R3 | Duplicate borders/position modifiers removed; regression-gated | Yes | Passed | Pending | Open |
| 37 | `AANONQxl95iZqtPVJOS54N0` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Use Mugsy instead of fire icon | R3 | Existing code-native Mugsy coach retained; fire remains sensory taxonomy only | Yes | Passed | Pending | Open |
| 38 | `AEQnB_3rqK5z7EX8cgiVadE` | 0.5.2 (3), iPhone17,1, iOS 27.0 | Repair tagging and search by name | R1/R3 | Existing display-name/account search and caller-bound tag RPC retained | Yes | Passed | Pending | Open |
| 39 | `ABG8g5YReSPF9Q6frmyWMBQ` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Put journal below caption in detail | R2 | Existing caption-first/private-note order retained | Yes | Passed | Pending | Open |
| 40 | `AN53QXd8EeYY6nWHv9sWMj4` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Show tagged profile picture | R2/R4 | Existing avatar projection retained and regression-gated | Yes | Passed | Pending | Open |
| 41 | `ACufZTtWjlVVFJEeI24fc24` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Add photo zoom | R2 | Existing full-screen photo viewer retained and regression-gated | Yes | Passed | Pending | Open |
| 42 | `AEGrCESnxmyyrJrT3DMLHSc` | 0.5.2 (3), iPhone18,1, iOS 26.6 | Make profile identity clickable | R2 | Accepted for Feed and Journal identity | Yes | Passed | Pending | Open |
| 43 | `ACAWYPJWgTrrqw9fVH1vu_w` | 0.5.2 (2), iPhone17,1, iOS 27.0 | Account deletion incomplete | R1 | Existing hardened deletion worker/step-up contract retained and regression-gated | Yes | Passed | Pending | Open |
| 44 | `AFa47DQy7rf5-HvXhhIv6lM` | 0.5.2 (2), iPhone17,1, iOS 27.0 | Post deletion does not work | R1 | Existing caller-bound delete-owned-visit RPC retained and regression-gated | Yes | Passed | Pending | Open |

## Locked acceptance rules

- Visual tab order remains Map, Feed, Add, Saved, Journal.
- Signed-in launch and onboarding completion default to Feed; deep links still
  override it, and guest Map/Saved access remains identifier-based.
- Publish preview geometry is unchanged.
- Share hub/sheet actions, structure, formats, templates, layout controls,
  ordering, defaults, privacy presentation, and collage behavior are unchanged.
- Criterion importance persists by account and criterion scope; visit scores do
  not persist.
- Publish keeps compact inline Audience, Raw note, and Tag people controls;
  private-note editing remains in the reflection flow.
- Reports remain open until replacement-build TestFlight acceptance.
