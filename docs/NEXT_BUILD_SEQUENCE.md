# Next Build Sequence

Date: 2026-07-03

Use this as the next Codex session handoff. Keep the next pass narrow.

## Goal

Finish the remaining private-beta validation gaps after the readiness pass, without expanding scope into Friends, notifications, widgets, Discover, or broad social graph work.

## Sequence

1. Start from `/Users/joe.rosso/Desktop/Projects/testMugshot` on the latest pushed backup branch.
2. Run `git status` and confirm no ignored config/secrets are staged.
3. Build and run on iPhone 17 Pro simulator.
4. Complete a fresh photo-backed Add Visit smoke with manual PhotosPicker selection or picker-capable automation. The 2026-07-03 XcodeBuildMCP tap path did not present the system picker even after seeding simulator media.
5. Verify the newly saved visit appears after relaunch in Profile Recent, Feed, and remote Visit Detail with the uploaded photo visible.
6. Smoke remote social controls with a beta account: like, unlike, add comment, save cafe from feed/detail, and preserve existing Want-to-Try state.
7. Smoke owner edit/delete on a throwaway remote visit.
8. Replace placeholder Settings legal copy with reviewed beta Privacy/Terms/About text.
9. Do a focused accessibility pass on Add Visit, Feed cards, remote Visit Detail, Saved, Mugsy empty states, and Settings.
10. Re-run build, tests, secret scan, diff review, and git status before the next push.

## Do Not Do In The Next Pass

- Do not build Friends.
- Do not restart Notifications.
- Do not import widgets.
- Do not merge old branches wholesale.
- Do not redesign the whole app.
- Do not make destructive Supabase changes.

## Exact Suggested Next Prompt

Continue Mugshot from `/Users/joe.rosso/Desktop/Projects/testMugshot`. Use the latest pushed private-beta readiness branch as source of truth. Complete the remaining validation gap from `docs/NEXT_BUILD_SEQUENCE.md`: run a manual or picker-capable fresh photo-backed Add Visit smoke, verify Profile Recent/Feed/remote detail after relaunch, smoke real social controls and owner edit/delete on throwaway data, update docs if needed, then build/test/secret-scan/diff-review and push a safe branch. Do not start Friends, Notifications, widgets, Discover, postcards, or broad social graph work.
