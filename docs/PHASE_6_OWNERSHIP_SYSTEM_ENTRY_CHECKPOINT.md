# Phase 6 — Ownership, Accessibility, and System Entry Checkpoint

## Outcome

Phase 6 is ready to advance under the roadmap's risk-informed checkpoint policy. Settings now organize durable preferences and ownership tools clearly, owner exports are caller-bound and RLS-constrained, account deletion removes Storage objects before the Auth user, and every new system entry point converges on the existing `SipDraft` and submission pipeline.

## Shipped in this checkpoint

- Settings organized into the nine roadmap groups, with task-specific choices kept inside the composer.
- Privacy, audience-default, map-unit, recap, accessibility, cloud-health, export, sign-out, and account-deletion surfaces.
- Owner-requested JSON export covering journal entries, separately stored private notes, recipes, TasteSignals, lists, friendships, preferences, and media references.
- Best-effort packaging of available photos alongside the machine-readable export, with unavailable media retained as references.
- Cloud-sync transparency for durable drafts, pending submissions, drink-analysis retries, and media cleanup.
- A repaired and redeployed authenticated account-deletion function that removes user Storage prefixes before deleting the Auth user.
- One persistent, authentication-safe system route contract for deep links, App Intents, App Shortcuts, and widgets.
- App Intents for Cafe Sip, Home Sip, Repeat Recent Sip, Brew Saved Recipe, and Open Journal.
- A small Quick Sip widget and a medium Cafe/Home/Repeat/Camera widget.
- Camera entry that opens the Guided composer at the photo-ready drink stage.
- Rating haptics that respect the durable accessibility preference.
- DEBUG Phase 6 control while the production build uses the completed settings path.

## Verification

- Swift unit suite: passed, including persistent system routing, every accepted deep-link mapping, shared draft initialization, independent Repeat/Brew timestamps, visibility rules, private-note payload isolation, and product-copy checks.
- Simulator Debug app and embedded widget build: passed on iPhone 17 Pro, iOS 26.2.
- App Intents metadata extraction: passed for the production app bundle.
- Guided Home deep link: passed.
- Camera deep link and photo-ready launch: passed.
- Authentication interruption: routes remain persisted until the signed-in app explicitly consumes them.
- Largest Dynamic Type plus Increase Contrast: all Settings groups remained labeled, reachable, and scrollable.
- Reduce Motion: app launch and camera route exercised with the system preference enabled; the existing composer motion policy uses fades or no spatial transition.
- Live owner export: 12 journal entries, 5 separately represented private notes, 11 TasteSignals, 6 friendship records, and all 37 available media references packaged for the signed-in test owner.
- Live Supabase owner-export contract: passed for caller ownership and cross-owner exclusion before and after security-invoker hardening.
- Live migrations:
  - `20260714055538_phase_6_owner_data_export`
  - `20260714061539_harden_owner_data_export_invoker`
- Live `delete-account` Edge Function: version 3, active, JWT verification enabled, and fetched deployment verified against the repaired source.
- Supabase security advisor: no errors and no warning attributable to `build_owner_data_export`.
- Product source scan: no accented cafe spelling or consumption-pressure copy.
- Privacy source scan: widgets, routes, and App Intents contain no caption or private-note data.
- `git diff --check` and plist/project validation: passed.
- Screenshot QA:
  - `phase-6-ownership/01-settings-groups.jpg`
  - `phase-6-ownership/02-data-export-sync.jpg`
  - `phase-6-ownership/03-home-deep-link.jpg`
  - `phase-6-ownership/04-camera-deep-link.jpg`
  - `phase-6-ownership/05-accessibility-xxxl-contrast.jpg`

## Recommended follow-up, not a blocker

- Run the App Shortcuts gallery and widget-gallery presentation on a physical device after Apple Developer signing configuration is finalized.
- Complete a human-led VoiceOver sweep on the supported physical-device matrix before an App Store submission.
- Add a single archive container if a future export must be shared as one file instead of JSON plus individual media attachments.
- Destructively exercise account deletion with a dedicated disposable test owner; the current signed-in owner's account was intentionally preserved.

## Risk decision

No privacy, data-loss, authentication, or unsafe-migration blocker remains. The export is actor-bound, runs as the caller, and passed cross-owner tests. System entries do not publish in the background or bypass audience confirmation. The remaining items are device-matrix and packaging refinements, so they do not justify holding final program acceptance.
