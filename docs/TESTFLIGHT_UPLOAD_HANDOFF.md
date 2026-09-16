---
document_type: living
status: current
last_verified: 2026-09-16
---

# TestFlight Upload Handoff

Use this format for every Mugshot TestFlight archive, upload, or testing-group
handoff.

TestFlight 0.5.3 (8) is the current beta. The exact `main` source at `e07cb5f`
passed its focused iOS 27 Simulator journeys, signed connected-iPhone build,
install, and launch gate, Release archive, and local App Store Connect export.
Xcode Organizer uploaded the archive on 2026-09-16 at 4:32 PM EDT. App Store
Connect completed processing and records build
`db5a2bb5-697c-40e6-9617-d8ba48825167` as `Testing` with a 90-day testing
window. Mugshot Team and Alpha Friends are assigned, the battery-focused testing
notes are published, and automatic tester notifications are enabled. Hands-on
TestFlight acceptance remains pending. No App Store release was submitted.

Build 8 packages both battery fixes, regular-weight captions, the **Your
ratings** Map legend, and the temporary central Add > Log a Sip > Home
under-construction placeholder. It does not change Supabase schema, environment,
or production data.

**Battery release hold:** Build 7 contains the confirmed continuous-location
lifecycle defect documented in the
[battery and thermal audit](audits/BATTERY_THERMAL_RUNTIME_AUDIT_2026-09-16.md).
Current source contains a locally verified remediation. The fixed development
candidate passed its first owner-observed charging and Map-to-lock battery arm:
it rose from 37% to 53% during ten plugged-in minutes with Mugshot open, then
remained at 53% during a 30-minute unplugged interval with two minutes on Map
followed by lock. This single arm has no matched control, uses coarse displayed
battery percentages, and did not include a temperature report.
Short physical Power Profiler and Logging captures verified the location-lifecycle
instrumentation and caught a source-only Home synchronization loop introduced
after build 7. That loop is fixed: settled sampled CPU fell from about 8.9% of one
core to about 0.02%, continuing post-launch network traffic stopped, and only one
Home synchronization ran. The privacy-safe instrumented Debug candidate remains
installed on the connected iPhone; it does not change Release analytics or
backend contracts. Matched force-quit, movement/reminder, media/upload, thermal,
and extended-discharge acceptance remain open. After the owner-observed charging
and Map-to-lock arm passed, the owner explicitly requested build 8 as the urgent
replacement TestFlight patch. Those remaining experiments stay documented as
follow-up evidence rather than a block on this owner-authorized beta replacement.

Build 8 also contains the merged product, moderation, sharing,
regression-repair, reaction, and explicit-profile-identity work. Test results
and unresolved acceptance items remain tracked in the
[feedback ledger](TESTFLIGHT_FEEDBACK_LEDGER.md).

## Build status

- Version/build: 0.5.3 (8)
- App Store Connect status: Testing; upload and processing complete
- Testing groups: Mugshot Team and Alpha Friends assigned
- Tester notification: Automatically notify testers enabled
- Build record: `db5a2bb5-697c-40e6-9617-d8ba48825167`

## What to Test — build 0.5.3 (8), published

> Battery and heat patch: leave Mugshot open while charging, then use Map and
> lock the phone for 30 minutes. Confirm charging progresses, battery remains
> stable while locked, and the phone does not become hot. Feed and detail
> captions should use regular weight, and the personal Map legend should say
> “Your ratings.” Add > Log a Sip > Home should show the temporary “Home is
> under construction” message and return to cafe logging. Confirm ordinary cafe
> logging and publishing still work. Existing Home/Recipes content in Journal
> must remain available and unchanged.

## Historical build-7 What to Test — published

> Welcome to Mugshot

## Historical example: Build 0.5.2 (3)

- App Store Connect status: Ready to Submit
- Internal testing: Mugshot Team
- External testing: Alpha Friends and Marketing Site not yet assigned

### What to Test — ready to paste

> Please focus on sharing a Mugshot through Messages. Share a Friends or
> Everyone post and confirm the message includes a tappable Mugshot link. With
> Mugshot installed, the link should open the real post in the iOS app. Without
> the app, it should open the same post on the web without requiring sign-in,
> with clear options to browse Mugshot or join TestFlight. Confirm the shared
> post's photos, author, drink, cafe, caption, rating, and tasting details are
> accurate. Private posts must remain unshareable by public link. Also check
> that Feed, Journal, Map, Saved, profile, photo loading, and existing post
> details still work normally. Please report broken or missing images, links
> that open the wrong post, unexpected sign-in prompts, exposed private
> information, or links that fail to open after relaunching the app.

## Notification candidate template

Use only after the exact candidate has passed Simulator and connected-iPhone
gates and the user has explicitly requested upload:

Source 0.5.3 (5) contains the v3 notification lifecycle but is not yet eligible
for upload. Deterministic verification and the Simulator runtime gate passed.
Signed build/install/launch, permission, active sandbox v3 registration,
preference-off removal/re-registration, terminated cold launch, one real
background sandbox send, unread Activity presentation, mark-one-read authority,
and in-app routing passed. That pass exposed a Feed bell that stayed stale until
activation. Its direct shared-store observation fix passed full-static 12/0/1
and a second signed-device delivery/read reproduction: the authoritative count,
Activity marker, and Feed bell cleared immediately without relaunch. Foreground
alert, visually observed background alert/app-icon badge, notification-tapped
cold launch, category suppression, sign-out, and the remaining device matrix
still remain.
Do not infer candidate readiness from the production worker being configured.

> Please focus on Mugshot Activity and iOS notifications. From a second test
> account, create normal friend-post, tag, like, comment/mention,
> friend-request, and collaborative-list activity. Confirm the recipient sees the correct in-app
> Activity item and, when its category is enabled, a notification. Test with the
> app open, in the background, and fully closed; tapping must open the intended
> Mugshot content for the signed-in recipient. Read one item and then all items
> and confirm both the Activity indicator and app-icon badge converge. Turning
> push or a category off must stop new push for that choice without removing
> in-app Activity. Signing out, switching accounts, blocking someone, or opening
> removed/private content must never expose another account's activity or
> content. Also confirm nearby cafe reminders still route correctly. Report
> missing or duplicate alerts, stale badges, wrong destinations, noisy friend-
> post volume, or any privacy or account mismatch immediately.
