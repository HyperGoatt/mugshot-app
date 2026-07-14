# Prioritized Build Plan

Date: 2026-07-02

Principle: protect the core loop first. Mugshot should reliably let a signed-in person capture a sip, save real data, relaunch, and see the memory in the right places before the app expands socially.

## P0 Private Beta Blockers

1. Add Privacy, Terms, About, support/contact, and sign-out access in a lean Settings surface.
2. Run and document fresh end-to-end no-photo and photo-backed Add Visit smokes before beta distribution.
3. Make Feed/Profile/Saved clearly distinguish real remote truth from local/demo fallback.
4. Hide, disable, or label read-only Feed/Detail social icons until remote like/comment mutations exist.
5. Add owner-safe remote Visit edit/delete or explicitly defer them with clear beta limitations.
6. Keep Supabase notification/push work blocked until the old embedded-token trigger/function path is rebuilt safely.
7. Add journey-level tests for Add Visit validation, Supabase payload mapping, and core remote detail rendering.

## P1 Core Product

1. Remote-backed Profile stats/top cafes so Profile is not half real and half local.
2. Stronger Add Visit error handling for partial photo upload and retry cleanup.
3. Cafe detail remote aggregate stats: visit count, average, popular drinks, last visit.
4. Remote like mutation, then remote comment mutation.
5. Better auth/profile setup: username collision handling, clearer email confirmation state, profile completion.
6. Map search reliability and better typed-cafe fallback.
7. Accessibility pass for Add Visit, remote Visit Detail, Feed cards, Saved, Map pins, and tab navigation.

## P2 Polish And Retention

1. Mugsy branded empty states in Saved, Feed, Profile Recent, Friends placeholder, and no-cafes states.
2. Taste memory improvements: favorite orders, reorder notes, personal tags, "would order again."
3. Personal history filters by drink, score, cafe, city, photo/no-photo, and date.
4. Friends MVP: friend search, requests, friend list, and friend-only visibility validation.
5. Public user profile read path after privacy choices are settled.
6. Better cafe discovery: nearby, visited, want-to-try, friend-loved, and map list.

## P3 Later Enhancements

1. Push notifications and notification center after backend safety work.
2. Craft Sip/home brew mode.
3. Discover/Spin for a Spot.
4. Postcard/share generator.
5. Widgets and app group work.
6. In-app feedback board and analytics expansion.

## Recommended Next Slice

Do a beta-hardening pass:

1. Settings/legal/about/sign-out.
2. Read-only social icon cleanup.
3. Fresh no-photo/photo Add Visit smoke.
4. Accessibility spot check.
5. Push that as the first private-beta readiness branch.
