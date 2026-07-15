# Mugshot UI/UX Polish Sprint

Date: 2026-07-14

## Guardrails

- Preserve Mugshot's cream, sage, espresso, serif, photography, glass, and Mugsy language.
- Strengthen the core loop: discover a cafe, remember a sip, revisit the memory, understand personal taste.
- Prefer existing data and services. Do not create a second social graph, recommendation engine, journal, or collection system.
- Keep private notes owner-only and make sharing choices explicit.
- Defer new animation choreography, spring tuning, and haptic design until the structural and visual work below is complete.
- Every loading, empty, success, error, and permission state must preserve useful context and offer a clear next action.

## Finding acceptance matrix

| # | Finding | Existing foundation | Acceptance evidence |
|---|---|---|---|
| 1 | Source-scoped map discovery | Personal map pins and discovery RPC sections | Map offers For You, Friends, Saved, and All scopes; each scope has truthful explanatory copy and data provenance. |
| 2 | Persistent list/map handoff | Map and Discovery List modes | Query, source scope, filters, selected cafe, and search region survive switching between Map and List. |
| 3 | Relationship-first cafe detail | Map preview sheet and full cafe detail | Primary hierarchy is cafe identity, Log a Sip, personal relationship/history, friend activity, then utilities. |
| 4 | Refined floating navigation | Custom glass dock with tab scrubbing | Selected state is unmistakable, Add remains visually primary, accessibility reports tab selection, and content remains visible behind the dock. |
| 5 | Mugsy-led conversational discovery | Ranked discovery reasons and Mugsy assets | Map can show one dismissible, preference-aware discovery question that changes the selected discovery scope or filter without adding a chatbot. |
| 6 | Visual taste calibration | Capture Preferences and preference persistence | Setup uses visual multi-select choices and clearly previews how choices affect the first useful Mugshot state. |
| 7 | Contextual location education | LocationManager, manual search, denied banner | The system prompt is preceded by a benefit sheet; Not Now keeps manual search available; denied access offers Settings and search. |
| 8 | Progressive composer disclosure | Guided four-step composer | Secondary actions appear only after required context; Quick and Tasting Lens paths remain distinct; drafts and privacy rules are preserved. |
| 9 | Focused memory ritual | Guided composer headings, progress, and success overlay | Each step has one clear question, progress and back behavior are accessible, and completion returns to Journal with the saved memory summarized. |
| 10 | Memory-first feed cards | Remote and local feed cards | Photo, drink, cafe, rating, and one memorable phrase dominate; author, recommendation reason, and social controls remain secondary. |
| 11 | Visual cafe collections | Shared lists, invitations, roles, reorder, cafe search | Lists have a visual cover treatment, count, visibility, collaborators, and map context without changing collaboration semantics. |
| 12 | Evidence-backed taste profile | Mugshot Passport and Taste Signal evidence | Taste Identity shows recent-period context, personal map footprint, and drill-down evidence; no competitive percentile scoring. |
| 13 | Monthly coffee recap | Reflection engine and detail view | Monthly recap tells a paced coffee story using existing visit history, comparisons, photos, places, and an explicit share action. |
| 14 | Branded Sip Card sharing | Text/photo sharing and ImageRenderer passport sharing | Visit sharing generates a Mugshot-branded image with drink, cafe, rating, date, and public caption only; private notes never render. |
| 15 | Photographic Journal archive | Timeline, calendar, and map archive modes | Timeline groups entries by month or week and adds photo strips while retaining search, filters, and direct visit access. |
| 16 | Effort-aware completion state | Composer success overlay and Mugsy assets | Saved confirmation identifies the sip and destination; a detailed memory receives richer facts than a minimal Quick Sip. |
| 17 | Layout-faithful loading | Shared loading cards and section spinners | Feed, Journal, collections, and cafe detail use placeholders shaped like their final layouts with no blocking full-screen spinner. |

## Verification gates

1. Build the app after every implementation phase.
2. Add focused unit tests for new pure models, filtering, recap formatting, privacy, and share-card content.
3. Add or extend UI tests for onboarding, location fallback, composer completion, map/list state, collection detail, and sharing entry points.
4. Capture the same representative states before and after changes on a current iPhone simulator.
5. Verify Dynamic Type, VoiceOver labels/order, contrast, keyboard behavior, and Reduce Motion fallbacks.
6. Run the full unit and UI test suites before declaring the sprint complete.

## Deferred animation phase

The follow-on phase will define shared-element transitions, sheet choreography, gesture physics, tab scrub haptics, rating feedback, success timing, and Reduce Motion substitutions. Structural code in this sprint should expose stable state changes without adding new animation systems.

## Implementation checkpoint

- All 17 findings are implemented in the app and test targets.
- The iOS app build succeeds without app-source warnings.
- The complete test plan passes on iPhone 17 Pro / iOS 26.2: 96 tests, 97 executions, zero failures, and zero skips.
- Discovery-source, Sip Card privacy, reflection, Taste Identity, and ASCII cafe spelling contracts have focused unit coverage.
- Guest gating, draft restoration, failed-save recovery, Saved-to-composer routing, the explicit completion action, and ten repeated Quick Sip runs pass in UI automation.
- Map, Feed, Saved, Journal, and the guided composer pass hit-region, element-description, clipping, and trait audits. The Map audit ignores only MapKit's system-owned `Legal` attribution target.
- Hands-on simulator QA covers Feed and Journal empty states, Map and List discovery, list-to-map search persistence, cafe detail hierarchy, Saved cards, guided capture, and the effort-aware completion state.
- The final Map-bearing UI rerun is free of SwiftUI state-during-update runtime warnings.
- Animation and haptic choreography remain intentionally deferred to the next phase.
