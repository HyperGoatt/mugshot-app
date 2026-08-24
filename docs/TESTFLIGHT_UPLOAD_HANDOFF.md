---
document_type: living
status: current
last_verified: 2026-08-24
---

# TestFlight Upload Handoff

Use this format for every Mugshot TestFlight archive, upload, or testing-group
handoff.

## Build status

- Version/build: `[VERSION] ([BUILD])`
- App Store Connect status: `[PROCESSING | READY TO SUBMIT | TESTING | OTHER]`
- Testing groups: `[GROUPS OR NOT YET ASSIGNED]`

## What to Test — ready to paste

> [Lead with the main new behavior in plain language. Name the exact user flow
> testers should exercise and the expected result. Follow with the highest-risk
> regression paths and failure states. Include privacy or access-control
> expectations when relevant. Keep the blurb under 4,000 characters and only
> describe behavior present in this build.]

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
for upload. Deterministic verification and the Simulator runtime gate passed,
but connected-iPhone sandbox acceptance is blocked until the replacement Debug
build is launched and exercised. The App ID capability is enabled, the
push-enabled profile is installed, and the signed app installed successfully;
runtime notification acceptance and the device matrix remain.
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
