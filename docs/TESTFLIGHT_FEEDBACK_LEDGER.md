---
document_type: living
status: current
last_verified: 2026-08-24
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
skip is the optional local `pglast` parser. A signed 0.5.3 (5) Debug app built
and installed on Joe's iPhone, but automated launch was denied because the
phone was locked. Report-level physical acceptance therefore remains Pending,
production configuration is unchanged, and every TestFlight report remains
Open.

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
| 10 | `AKAR-CG0cAdOkRcnj7qR6uk` | 0.5.3 (5), iPhone18,1, iOS 26.6 | Persist More/Most/Less importance | R3 | Adjusted: criterion pins persist; importance resets per visit | Yes | Passed | Pending | Open |
| 11 | `ADMa6OZntf6tstz1-bTojuQ` | 0.5.3 (5), iPhone18,1, iOS 26.6 | Edit every Publish summary without navigating back | R3 | Accepted | Yes | Passed | Pending | Open |
| 12 | `AIPBqNqY8TO6z5hDLt0Zi6I` | 0.5.3 (5), iPhone18,1, iOS 26.6, text-only | Keep caption on Publish | R3 | Accepted | Yes | Passed | Pending | Open |
| 13 | `ADQ2JCLsXZ3-SXzNkhR1jNk` | 0.5.3 (5), iPhone17,1, iOS 27.0 | Reconcile duplicate cafe/address variants | R1 | Accepted; text fallback is address-order invariant | Yes | Passed | Pending | Open |
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
- Reports remain open until replacement-build TestFlight acceptance.
