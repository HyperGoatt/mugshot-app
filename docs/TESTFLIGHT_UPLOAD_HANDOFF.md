---
document_type: living
status: current
last_verified: 2026-08-26
---

# TestFlight Upload Handoff

Use this format for every Mugshot TestFlight archive, upload, or testing-group
handoff.

Organizer and the cached Xcode feedback packages confirm tester use of 0.5.3
(5). The completed 44-report remediation candidate is 0.5.3 (6). On 2026-08-26
the owner explicitly authorized its Simulator and connected-iPhone release
gates, archive/upload, and Alpha Friends assignment. No archive, upload,
processing, or assignment result is claimed until that step succeeds. Every
report remains open until the replacement build is accepted; see the
[feedback ledger](TESTFLIGHT_FEEDBACK_LEDGER.md).

Current remediation evidence includes 425 unit tests, eight focused Simulator
UI journeys, all 43 screenshot reports plus the text-only report, later focused
profile/feed checks, and consolidated Simulator acceptance. Earlier signed
Debug sources built, installed, and launched on the connected iPhone. The exact
build-6 source must still pass both release runtime gates before upload. The
reaction migration is not production-configured.

## Build status

- Version/build: 0.5.3 (6)
- App Store Connect status: Not uploaded
- Testing groups: Alpha Friends requested; not assigned

## What to Test — ready to paste

> Welcome to Mugshot!

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
