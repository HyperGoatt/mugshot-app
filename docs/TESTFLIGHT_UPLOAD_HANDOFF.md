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

## Build 0.5.2 (3)

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
