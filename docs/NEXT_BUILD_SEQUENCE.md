---
document_type: historical
status: superseded
superseded_by: CURRENT_SPRINT.md
---

> Historical build sequence. Use [Current sprint](CURRENT_SPRINT.md) for active ordering.

# Next Build Sequence

Date: 2026-07-03

Use this as the next Codex session handoff. Keep the next pass narrow.

## Goal

Finish the remaining private-beta hardening gaps after the readiness pass and fresh photo-backed smoke, without expanding scope into Friends, notifications, widgets, Discover, or broad social graph work.

## Sequence

1. Start from `/Users/joe.rosso/Desktop/Projects/testMugshot` on the latest pushed backup branch.
2. Run `git status` and confirm no ignored config/secrets are staged.
3. Build and run on iPhone 17 Pro simulator.
4. Keep the 2026-07-03 photo-backed smoke as the baseline: visit `587f8423-a56f-46fe-b15a-452b2f024ebf` uploaded 1 photo, appeared after relaunch in Profile Recent and Feed, and opened remote Visit Detail with the photo visible. XcodeBuildMCP tap/touch did not present PhotosPicker, but Computer Use coordinate-click fallback did.
5. Smoke remote social controls with a beta account: like, unlike, add comment, save cafe from feed/detail, and preserve existing Want-to-Try state.
6. Smoke owner edit/delete on a throwaway remote visit.
7. Replace placeholder Settings legal copy with reviewed beta Privacy/Terms/About text.
8. Do a focused accessibility pass on Add Visit, Feed cards, remote Visit Detail, Saved, Mugsy empty states, and Settings.
9. Re-run build, tests, secret scan, diff review, and git status before the next push.

## Do Not Do In The Next Pass

- Do not build Friends.
- Do not restart Notifications.
- Do not import widgets.
- Do not merge old branches wholesale.
- Do not redesign the whole app.
- Do not make destructive Supabase changes.

## Exact Suggested Next Prompt

Continue Mugshot from `/Users/joe.rosso/Desktop/Projects/testMugshot`. Use the latest pushed private-beta readiness branch as source of truth. The fresh photo-backed Add Visit smoke is complete; continue with beta hardening only: smoke real social controls and owner edit/delete on throwaway data, replace placeholder legal copy if reviewed text is available, do focused accessibility checks, update docs if needed, then build/test/secret-scan/diff-review and push a safe branch. Do not start Friends, Notifications, widgets, Discover, postcards, or broad social graph work.
