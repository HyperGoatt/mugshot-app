# Next Build Sequence

Date: 2026-07-02

Use this as the next Codex session handoff. Keep the next pass narrow.

## Goal

Prepare the native app for a small private beta by hardening the real core loop and removing misleading beta risks.

## Sequence

1. Start from `/Users/joe.rosso/Desktop/Projects/testMugshot` on the latest pushed backup branch.
2. Run `git status` and confirm no ignored config/secrets are staged.
3. Build and run on iPhone 17 Pro simulator.
4. Add a lean Settings surface with Sign Out, About, Privacy, Terms, and support/contact.
5. Clean up Feed/remote Visit Detail social controls so read-only actions are not misleading.
6. Add or update tests for Add Visit validation, read-only social presentation, and config hygiene.
7. Run a fresh no-photo Add Visit smoke.
8. Run a fresh photo-backed Add Visit smoke if the Photos picker is reachable.
9. Do a focused accessibility pass on Add Visit, Feed cards, remote Visit Detail, Saved, and Settings.
10. Update `docs/CURRENT_PRODUCT_STATUS.md` and `docs/FEATURE_STATUS_MATRIX.md`.
11. Build, run tests, review diff, scan for secrets, commit, and push a clean branch.

## Do Not Do In The Next Pass

- Do not build Friends.
- Do not restart Notifications.
- Do not import widgets.
- Do not merge old branches wholesale.
- Do not redesign the whole app.
- Do not make destructive Supabase changes.

## Exact Suggested Next Prompt

Continue Mugshot from `/Users/joe.rosso/Desktop/Projects/testMugshot`. Use the latest pushed audit branch as source of truth. Implement the beta-hardening slice from `docs/NEXT_BUILD_SEQUENCE.md`: add lean Settings/legal/about/sign-out, clean up read-only social controls, add focused tests, validate build/tests/simulator, update docs, and push a safe branch. Do not start Friends, Notifications, widgets, or a broad redesign.
