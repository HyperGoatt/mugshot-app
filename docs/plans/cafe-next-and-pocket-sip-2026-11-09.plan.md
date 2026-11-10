# Cafe detail, The Next Sip and Pocket Sip

## Goal

Integrate the approved Mugshot Lab experience into the existing iOS app. A cafe opens at full height from Map or Saved. A returning visitor can start from their latest order, and a person with coffee photos can keep a private draft from Add or directly from Photos.

## Implementation

1. Give Map and Saved a common cafe layout with a source-aware Back button, a clear primary action, and the cafe's existing actions and history further down. Cover first visits, repeatable orders, and orders marked Wouldn't reorder.
2. Create The Next Sip as a new private draft. Use the latest eligible order at that cafe owned by the active person. Copy the drink and order details, date the draft today, and keep today's photo, rating, and reflection empty. Keep the original sip accessible.
3. Put Pocket Sip in Add with the native multi-photo picker. Let Photos hand off images through the existing Save to Mugshot extension. Send both into the same account-scoped draft library and provide confirmation only after local storage succeeds. Preserve place sharing.
4. Verify both cafe routes and both photo routes on Simulator. Test ownership, cancellation, bad inputs, handoff retry and persistence across relaunch. Run the repository documentation and applicable static checks before publishing the feature branch.

## Documentation impact

This changes product behavior, local data ownership, privacy, and the existing share extension's activation contract. Update the changelog, current product status, real data flow, and sharing guidance. Keep the existing app group and signing configuration. No Supabase changes are required.

## Verification

- The signed Debug Simulator build contains the app and the existing share extension. The app and extension carry the same simulated app-group entitlement.
- The iPhone 17 Pro Simulator on iOS 27.0 passed 44 focused unit tests and eight UI tests. The UI tests exercised Map pin open and Back, Saved handoff, the original sip, the first-visit and declined-order states, accessibility text size, Pocket Sip cancellation, and repeat draft reopening. A follow-up test passed after editing the repeated order details and reopening that draft after termination.
- A separate iPhone 17 Pro Simulator on iOS 26.3.1 used local fixtures to open the cafe from Map and Saved, add one photo to the repeat draft, save a two-photo Pocket Sip through the native Add picker, and share three distinct images from Photos while Mugshot was terminated. Relaunch preserved all three drafts. The imported photos matched the three staged JPEGs in order, and Mugshot acknowledged the handoff after committing the private draft. A Safari URL share opened the existing Save cafe search flow.
- Storage coverage includes owner switches, stale extension sessions, account deletion, cancellation, invalid photos, ordered bytes, retry after a failed commit, and replay after draft edits or cleanup.

## Cafe detail crash follow-up

**ECC RED:** Two build 10 crash reports from the iPhone 16 Pro on iOS 27.0.1
matched the installed binary. Opening a cafe pin exhausted the main-thread
stack inside the shared SwiftUI detail layout builder. The original Simulator
journey passed, and the physical check stopped at launch, so neither caught it.

The patch builds only the selected layout behind its own SwiftUI view. Map and
Saved retain the redesigned layout, and older entry points keep their existing
sheet sizes. Layout selection, navigation, account checks, and draft storage
keep the same contracts. The opt-in owner-device test taps a real pin, goes
back, opens it again, and checks the Saved route. It uses the installed app
without fixture launch flags or edits to owner content.

**ECC GREEN for cafe navigation:** Mugshot Luna QA **0.5.3 (11)** replaced
build 10 in place on iPhone 16 Pro / iOS 27.0.1. The device reported build 11,
and the app, share extension, and widget passed signing and provisioning checks.
All 40 Application Support files and both preferences files matched their
backups, and the app-group inventory was unchanged. The hardware test opened
the same native Map pin twice, opened a Saved cafe, checked the page and Back
each time, and confirmed the app remained active. No new Mugshot crash report
appeared in the device inventory after the test. The signed app's debug
library SHA-256 is `fde52debb8c320fdfe3f2104c67e53addc5cdf8fd491abdade61238cf27ce755`.

**ECC RED for repeat edits:** On the iOS 27 Simulator, the field showed the
completed edit before termination, but the draft reopened without the final
character. Saving from the input binding alone passed on iOS 26.3.1 but still
missed the last character on iOS 27.0.

**ECC GREEN for repeat edits:** The field now keeps the typed wording without
keyboard autocorrection and saves through the existing owner-scoped store
during the input event. On a clean iPhone 17 Pro / iOS 27.0 Simulator the
regression test passed twice: it edited the order, terminated immediately,
reopened the one existing draft, and checked the entire value. The local draft
file contained the final edit before termination on both runs. The Map recents
test now uses the redesigned **Back to Map** control and still checks that the
search UI leaves the background and returns after Back.

The final clean Simulator pass covered **44 focused unit tests and 10 UI
cases**, with the repeat order case run twice. These checks covered Map pins,
Map and Add recents, the Saved handoff, accessibility text size, first visits,
declined orders, original sip navigation, Pocket Sip cancellation, private draft
storage, ordered media, account boundaries, and recovery. The original native
Photos picker and share extension journeys are recorded above; the crash
repair did not change either capture route.

Mugshot Luna QA **0.5.3 (12)** contains both fixes and replaced build 11 in
place. Source: `d3dd140a0a671dc8c632d7725bc583aaaddd66da`. The debug library
SHA-256 is `3cb7bc909d744d725f5b209b3a3df0b640034f915f0e09e86cdc79afeba80651`.
The device reported build 12 and the app launched. All 41 Application Support
files, both preferences files, and the shared container inventory matched the
private preinstall backup. Signature, provisioning, and bundle checks passed
for the app and both extensions. After a normal relaunch cleared an open
recipe detail, the build 12 read-only test opened the same Map pin twice and
a Saved cafe, used Back each time, and verified Mugshot remained active.

## Signed iPhone install

Historical build 10 receipt. Use the [crash follow-up](#cafe-detail-crash-follow-up)
for the current cafe QA candidate.

On November 9, Mugshot Luna QA **0.5.3 (10)** replaced build 9 in place on the
owner’s iPhone 16 Pro running iOS 27.0.1. The iPhone restart restored the existing
pairing over Wi-Fi. The signed build uses source
`9d5f1d7adfab9c163991c414edf730bad8eb26c2` and development bundle
`co.mugshot.app.dev`. Its debug library SHA-256 is
`41faff9deba6f04faafaf98191a725485e195eeb9c6e01a08a8105727f2c961d`.
Signature, provisioning, version, and entitlement checks passed for the app,
share extension, and widget. Analytics is disabled in this development build.

All 40 Application Support files, the app preferences file, and the app-group
preferences file matched their private preinstall backups byte for byte. The
app-group inventory matched and the Documents directory was empty. The device
reported build 10. CoreDevice launched the app and confirmed the process was
running.

For owner QA, open a cafe from Map and Saved and tap **Log this again** on a
repeatable order. Try **Add → Pocket Sip** and **Photos → Share → Mugshot**,
then reopen each private draft under **Add → Your drafts** or **Journal → Drafts**.

## Release boundary

The candidate is stacked on the Home library branch. Signed installation and
launch are separate from opening the cafe detail on the device. The repeat and
photo draft journeys on hardware, authenticated production behavior outside the
observed checks, and TestFlight acceptance are separate gates.
