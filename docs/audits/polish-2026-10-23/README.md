---
document_type: historical
status: audit-and-proposal
observed_at: 2026-10-23
---

> Implementation follow-up: [Signature Polish Sprint acceptance ledger](../signature-polish-sprint-2026-10-23/ACCEPTANCE.md). This audit retains its original baseline observations.

# Mugshot polish audit and first-pass plan

**Verdict:** Mugshot's identity is already distinctive. Its biggest opportunity is to make the quality of its feedback as consistent as its visual character. Keep the warm editorial type, coffee photography, sage/cream palette, native maps, optional reflection, and canonical Mugsy. Give small actions a crisp response, carry context between screens, and give a completed memory a brief, truthful acknowledgment.

**Delivery state:** Audit and recommendations only. No app behavior, backend contract, release configuration, or TestFlight state changed. The treatments and timings below are proposals, not implemented or measured results. Current implementation and release authority remain [Current product status](../../CURRENT_PRODUCT_STATUS.md) and the relevant living specifications.

[Open the screenshot walkthrough](gallery.html). All images are baseline captures from this audit, not proposed designs. Each recommendation below names its evidence and implementation entry points.

## Scope and evidence

- Source: clean Home V4 checkout, branch **codex/home-sip-v4**, commit **521f532**, inspected on October 23, 2026.
- Runtime: one current Debug build; iPhone 17 Pro Simulator on iOS 27.0. The built bundle identifier was read from the installation result: **co.mugshot.app**. This isolated Simulator bundle is separate from the owner's connected development iPhone.
- Production screens were walked with existing local test fixtures. Home was followed through an unrated, photo-free, private local save; Cafe through separate sip/cafe ratings and review. Saved loading, offline, failure, and accessibility text-size states used existing deterministic fixtures. People and Edit used existing DEBUG preview hosts and are identified as previews.
- No customer account was signed in. No live cafe post, comment, invitation, account change, external share, or backend write was submitted. Map tiles may load normally. No Supabase environment was intentionally queried or modified.
- Static source inspection complements screenshots for feedback triggers, routing, Reduce Motion, persistence boundaries, and supporting screens. Screenshots do not prove tactile feel, animation frame pacing, actual VoiceOver speech, production recovery, or device performance.
- Capture gaps: onboarding page 7 was not retained; the other eight panels were inspected. Authenticated Lists, Activity, public sharing, notification delivery, account recovery, and camera hardware were reviewed in source, not completed live. These are explicit acceptance gaps, not runtime passes.
- Screenshot 20 contains a deliberately plain test photo; its solid color is fixture content, not an image-loading defect. Screenshot 31 is an isolated recovery preview, not a broken full-app layout. Optimized captures are 368 × 800; the authentication capture retains the full Simulator image.

Documentation classification: historical audit/planning evidence, with no implemented product-behavior impact. The documentation index and changelog are updated for discoverability. App verification tiers for future implementation are specified below.

## Direction: a well-made coffee ritual

Borrow Duolingo's clarity of cause and effect and sense of accomplishment. Express that through Mugshot's own culture: the satisfying certainty of setting down a cup, saving a place, noticing a flavor, or keeping a memory. Frequent actions remain almost instantaneous. Mugsy is attentive and occasionally expressive; he does not compete with the drink or the person's writing.

Three levels of response:

| Moment | Proposed response | Boundaries |
| --- | --- | --- |
| A small choice | Immediate selected state; 100–180 ms local settle; one selection tick when useful | No success notification or full-screen response |
| A meaningful local commit | Stable button changes to a check; one success haptic after durable save; brief receipt | Do not imply remote sync or publication |
| A finished multi-step memory | One 600–900 ms Mugsy response integrated with the receipt/detail transition | No forced delay, repeat loop, points, streak, reward system, or new completion screen |

Existing large celebrations are not proof that the active V4 path uses them. The actual Home V4 save opens canonical detail; the older Home saved surface and generic completion card are separate code paths. Polish the active routes first.

## Screen-by-screen and flow-by-flow findings

Health here describes the observed finish, not release certification. **Strong** means preserve and refine; **Mixed** means a noticeable polish opportunity; **Needs attention** means misleading or inconsistent feedback.

| Step | Screen / action | Health and current observation | Evidence / recommendations |
| --- | --- | --- | --- |
| 1 | First-launch introduction, panels 1–6 and 8–9 | Strong visual personality; eight inspected panels are predominantly authored artwork. Native hit regions work, but raster text cannot reflow with Dynamic Type. Nine panels give repeated Continue taps considerable weight. | Gallery 30; R15 |
| 2 | Authentication / account entry | Warm, welcoming Mugsy and native provider controls. At the initial viewport the email form sits well below the hero/preview. Busy, validation, and recovery feedback should stay adjacent to the active form. No credentials entered. | 00; R16 |
| 3 | Main tab shell | Clear destinations and memorable central Add. Loaded tabs retain state. Some controls use local press styles, others plain styles. Avoid animating the entire page on every switch. | 01, 03, 05, 08; R3, R11 |
| 4 | Feed and scope selection | Strong photography and post hierarchy. Header is crowded by four utilities and a narrow subtitle. Source gives remote reactions an immediate impact plus a later success notification. Refresh already has a coffee-fill interaction and threshold haptic. | 03; R4, R11, R12 |
| 5 | Sip detail / comments / taste breakdown | Strong editorial composition and clear collapsible breakdown. Action feedback spans a shared detail surface and parent handlers; audit event ownership before adding cues. | 04; R4, R13 |
| 6 | Map / pin / cafe sheet | Native MapKit and earthy rating pins fit well. Keep loaded map clear. A selected pin and its presented cafe should feel connected without moving the geographic coordinate. Search and location recovery need a stable status location. | 08, 02, 21; R8, R12 |
| 7 | Saved library / filters / favorites / Want to Try | Useful cards and local optimistic state/Undo already exist. Two segment rows, search, and sort/density controls precede the first card. Mutation path has no explicit haptic; visual acknowledgment differs from detail. | 01; R7, R11 |
| 8 | Cafe detail / private note | Native compact sheet works; utility labels are small and the note status is understated. Save note does more than saving text: it also adds Want to Try. Preserve that explanation in feedback. | 02; R7, R8 |
| 9 | Journal / context filters | Strong recent-sip presentation. Personal identity and stats provide context. A new local Home save should land with continuity and a clear receipt rather than feeling like an unrelated detail page. | 05, 19; R6, R11 |
| 10 | Profile / taste identity | Rich, recognizable profile. At default size the horizontal stat row truncates the sip-average label. Keep editorial type and charts; improve semantic labels and wrapping. | 06; R2, R11 |
| 11 | Settings | Calm grouping is appropriate. Preserve native forms, switches, and destructive confirmations. Fixed small captions and mixed status patterns need consistency; existing setting is specifically Rating haptics. | 07; R2, R4, R14 |
| 12 | Composer setup / photo / cover / cafe search | Clear context selection and auto-draft reassurance. Adding a photo introduces a new row plus another tall photo tile. Cover/reorder states should read immediately; no-photo copy later says Oops even when photos were optional. Cafe search says Tap Near me although the action is Find me. | 09, 20, 21; R3, R9, R10, R12 |
| 13 | Home setup / starter / drink composition | Excellent method-specific identity. Starter selection changes a substantial portion of the setup. Keep method and drink context anchored while the detail panel settles. | 10, 11; R5, R10 |
| 14 | Home Make / timer | Monospaced timer and useful targets are strong. Start/stop/finished actions merit restrained acknowledgment. No decorative animation should compete while making a drink. | 12; R10 |
| 15 | Home Actuals | Strong explicit Unknown, Planned, and As planned distinctions; optionality is clear. Confirming a target should animate just that row to its recorded state. | 13; R1, R10 |
| 16 | Home Capture after blank Actuals | Needs attention. The next screen displays 18 g in · 36 g out · 28 sec without labeling those values as targets, despite leaving every actual unknown. This is an observed presentation ambiguity, not proof that persistence wrote false actuals. | 13 → 14; R1 |
| 17 | Sip rating / criteria / journal note | Good optional detail and personality. Unrated displays 0.0. The active V3 half-star control updates state but contains no haptic or motion treatment; older rating controls elsewhere do use the Rating haptics preference. | 15, 22 and source; R1, R4, R9 |
| 18 | Home make-again / With a tweak | Thoughtful existing distinction from rating. The optional next-time field appears immediately beneath selection. Refine continuity and focus without turning it into a required coaching step. | 16 → 17; R5, R9 |
| 19 | Cafe reflection | Clear separation between drink and place. A repeated large Mugsy nudge precedes each rating; supporting chips and control captions compete for space. Keep the score primary and feedback specific to the changed criterion. | 23; R9, R11 |
| 20 | Home Review | Needs attention. Header says Review the memory before it reaches your people, top progress says Share, but the action is Save to journal / Only you will see this. A deliberate photo omission is framed as Oops. | 18; R1, R6 |
| 21 | Cafe Review / audience | Photo and identity are clear. Actual audience and caption requirements sit lower than the first viewport; disabled footer gives a generic Finish the required details rather than naming the missing caption. No publication submitted. | 24 plus source; R6, R12 |
| 22 | Home saved detail | Durable local save opens canonical detail. Unrated is correctly shown here, but the acknowledgment is a small Saved here · Sync pending banner below the hero. The moment feels quieter than its importance. | 19; R6 |
| 23 | Edit Sip | Preview shows useful cover, caption, and criterion editing. Source dismisses on successful save; destination acknowledgment should make completion visible. Preview did not exercise a remote edit. | 33; R13 |
| 24 | People / requests / suggestions | Preview has warm social identity. Request explanation and suggestion reasons truncate at default size. Accept/Add need row-specific committed-state feedback without turning connections into rewards. | 32; R2, R13 |
| 25 | Saved truly empty | Friendly Mugsy, useful Explore Map and Log a Sip actions. Sort/density tools and 0 cafes have little value before the first item. Source uses a static model, so a one-shot entrance is an opportunity, not an existing behavior. | 25; R12 |
| 26 | Saved first load | Calm static skeletons are a strength. Count still says 0 cafes while data is unknown. Skeleton dimensions should converge with real cards to avoid reflow. | 26; R12 |
| 27 | Saved offline with cache | Strong: cached cards remain visible and a compact Retry banner explains the condition. Avoid replaying warning haptics on background retries. | 27; R12 |
| 28 | Saved failure without cache | Needs attention. Load failure and No favorites yet appear together. The app cannot infer an empty library from failure. Retry competes with unrelated exploration actions. | 28; R12 |
| 29 | Saved accessibility text size / Reduce Motion override | Strong menu substitution for filters and stacked layout. Much less content fits above the bottom bar; verify reachability by scrolling and actual VoiceOver separately. Header, bottom navigation, and small captions need a wider typography pass. | 29; R2, R14 |
| 30 | Interrupted-publication recovery | Source distinguishes unfinished publication from posted content with unfinished local cleanup. Preview is truthful but dense, with technical references and small inline actions. Preserve publication safety boundaries. | 31; R12, R14 |

### Supporting surfaces reviewed in source

These are included in the plan, with runtime acceptance still open. A source review is not a completed live journey.

| Surface family | Source reviewed | Finding and treatment to carry forward |
| --- | --- | --- |
| Recipe Book, recipe detail/editor, linked component, history/compare, serving | HomeRecipeExperienceView, HomeRecipeDetailScreens, HomeRecipeEditorView, HomeAttemptCanonicalDetailView, HomeAttemptPostSurface, HomeSharedRecipeScreen | Reuse R5/R10/R13 for selection, local-save receipt, and pending recipe change. Preserve attribution, immutable versions, and separate batch/serving identity. Do not polish superseded workbench routes as if they were the central V4 flow. |
| Elsewhere reflection | LogASipV3ProductionViews | Reuse the current setup → sip → context → review structure; preserve optional exact location. Apply the same rating, direction, and review-state treatments. |
| Activity / reactions / reaction people / recommendations / comments | ActivityCenterView, ReactionPeopleView, RecommendToFriendView, FeedTabView, RemoteVisitDetailView, SipDetailScreen | Keep optimistic actions quick. Use row-local working/error states; after confirmed comment send clear input and reveal the actual comment once. Read all should update count and label without a celebration. |
| Share hub, shared post, profile sharing, public links | MugshotShareHubView, CanonicalMugshotLinkRouteView, ProfileShareHubView, SharedProfileView | Reuse R6/R13 for preparation → ready → native share sheet. Closing a share sheet is not proof of sending. Keep external-audience acknowledgment and restricted/unavailable states explicit. |
| Private/shared/public cafe lists and membership | SharedCafeListsView, PublicCafeListsView, SavedCafeLibraryView | Lists did not open in the unsigned fixture; source review only. Selection check should acknowledge membership once. Invitation, membership save, and public access are separate states; keep failed rows recoverable. |
| Taste Passport / preferences / reflection reminders | TastePassportViews, ReflectionPreferencesView, JournalReflectionViews | Preserve evidence-based taste identity and optional reflection. Use one reveal when visible, then stay still. Do not imply knowledge before supporting data exists or introduce a new progress game. |
| Camera, library picker, bag scan | CameraCaptureView, PhotoLibraryPickerView, SipComposerView | Existing permission/unavailable states and native capture remain. Apply R10 on selection/capture, preserve photo order, and do not claim hardware haptics or camera acceptance from Simulator. |
| Account/profile setup, blocked users, moderation, support, export/delete, notifications/location | AuthEntryView, RequiredProfileSetupView, SettingsView, Phase6SettingsViews, NotificationSettingsView, BlockedUsersSettingsView, SocialSafetyViews | Reuse status and type improvements. Privacy, safety, consent, account deletion, and permission dialogs remain calm and explicit. No mascot celebration, euphemistic destructive labels, new permissions, or access changes. |

## Prioritized recommendations

Effort is approximate focused engineering time, including local checks, assuming existing components and no backend migration. **S:** up to half a day; **M:** roughly 1–2 days; **L:** roughly 3–5 days. Shared work overlaps; these estimates must not be added as independent project commitments. Expected impact is a design judgment, not a measured retention claim.

### R1 — Make every displayed state mean exactly what happened

**Priority:** P0, first pass. **Effort:** M. **Impact:** High trust and comprehension; noticeable without adding visual complexity.

**Weakness:** Unknown Home actuals become an unlabeled target summary; optional ratings show 0.0; private review uses social sharing language; intentional photo omission gets Oops.

**Treatment:** When actuals are blank, label the capture summary Planned setup, retaining each measured value only when it is actually recorded. Unset ratings show Not rated with empty stars and an accessible Not rated value. Home private review says Review your sip / Save this memory to your private journal; its progress state says Review. Keep the existing audience-specific Cafe review. Use No photo this time with Mugsy holding the camera, without implying an error. When a caption is required, the footer names it directly: Add a caption to continue.

**Trigger and response:** These are state-derived labels visible on entry and updated immediately when the underlying state changes; no celebratory motion or haptic. Do not change scoring, optionality, visibility defaults, or persistence semantics.

**Entry points:** [Home capture/review](../../../testMugshot/Views/Add/LogASipV3ProductionViews.swift), [rating control](../../../testMugshot/Views/Components/MugshotV3ReflectionComponents.swift), [photo placeholders](../../../testMugshot/Views/Components/MugsyPhotoPlaceholderView.swift). Evidence 13–19, 23–24, 33.

### R2 — Repair legibility and make type respond as well as layout

**Priority:** P0, first pass for shared controls; P1 for the wider pass. **Effort:** M. **Impact:** High accessibility and perceived precision.

**Weakness:** PrimaryButtonStyle uses white 16-point semibold text on sage #6E8F7C: calculated contrast **3.57:1**. Sage text on cream is **3.32:1**. Some Saved controls already use darker sage; the family is inconsistent. Numerous fixed system sizes do not scale. Profile and People labels truncate.

**Treatment:** Preserve sage for surfaces and artwork; use the existing darker #4D6F5D companion for text or an appropriate darker filled control. White on that darker token calculates **5.60:1**; darker sage text on cream **5.21:1**. Verify composited states separately. Use semantic text roles or metrics relative to those roles, keeping the system-serif display identity. Let stat labels wrap or use the full Sip average label in an adaptive grid. Give request explanations and suggestion reasons two lines. Keep small visual glyphs but provide generous independent hit areas.

**Trigger and response:** No animation on text-size changes beyond native behavior. Reflow without truncating critical actions or pinning them behind the footer. Preserve the existing Saved menu pattern at accessibility sizes.

**Entry points:** [DesignSystem](../../../testMugshot/Design/DesignSystem.swift), [colors](../../../testMugshot/Design/BrandColors.swift), [Profile](../../../testMugshot/Views/Profile/ProfileTabView.swift), [People](../../../testMugshot/Views/Feed/PeopleDiscoveryHubView.swift). Evidence 02, 06, 18, 29, 32.

### R3 — Give common controls one crisp physical response

**Priority:** P1, first pass. **Effort:** S–M. **Impact:** High across nearly every session.

**Weakness:** Primary/secondary styles already scale to 0.98, but many prominent controls use plain/custom styles. Shared styles do not consult Reduce Motion. Pending labels/spinners can resize controls.

**Treatment:** For primary, secondary, icon, and choice controls, change tint/opacity on touch-down immediately. Where motion is allowed, compress to 0.98 over about 80 ms and settle on release in 140–180 ms with very little overshoot. Keep hit areas unchanged. Pending buttons retain their height, width, and label alignment; replace the icon slot with a spinner. Disabled controls have no press response. Native system controls keep their native feedback.

**Trigger and response:** Touch-down only changes appearance; activation owns the action and any haptic. Cancellation restores the visual state and fires no commit cue. Reduce Motion uses tint/opacity with no scale. Do not place an impact generator inside a shared button style.

**Entry points:** DesignSystem, shared icon/buttons, composer footer, Saved controls. Evidence 01–02, 09–18, 24.

### R4 — Make the signature half-star rating satisfying; make other haptics quieter

**Priority:** P1, first pass. **Effort:** M. **Impact:** Very high for Mugshot's most distinctive repeated interaction.

**Weakness:** Active V3 half-star rating lacks the sensory feedback used by older controls. Remote reactions can emit an impact and later success vibration; detail and parent handlers both need ownership review. The generic completion card couples its haptic to the visual animation branch, suppressing that cue under Reduce Motion.

**Treatment:** On a changed half-star value, fill the new fraction immediately, crossfade the number over 100 ms, and settle only the affected star from 1.04 to 1 over 140 ms. Play one selection tick for a user-committed changed value, honoring the existing Rating haptics preference. Re-tapping the same value and restoring a persisted rating are silent. A criterion pin gets a small fill/check change and one light selection cue. For like/save toggles choose one local selection/soft cue; remove the later routine success vibration. Reserve success patterns for durable saves or meaningful confirmed actions. Keep success haptics independent of Reduce Motion.

**Trigger and response:** Own the event at the control or mutation boundary, not in both. VoiceOver increments/decrements use the same value transition, respect bounds, and never animate all five stars. No haptic trains during loading, retry, scrolling, or idle.

**Entry points:** [MugshotV3ReflectionComponents](../../../testMugshot/Views/Components/MugshotV3ReflectionComponents.swift), [motion/haptics](../../../testMugshot/Design/MugshotMotionSystem.swift), FeedTabView, RemoteVisitDetailView, MugshotExperienceState. Evidence 15, 22–23 plus source. Hardware feel remains untested.

### R5 — Make forward, back, and in-place expansion explain the change

**Priority:** P1, first pass. **Effort:** M. **Impact:** High continuity through the core flow.

**Weakness:** The step transition always inserts from trailing and removes to leading, including back. Some in-place reveals change height abruptly. Large stacked header/progress/keyboard changes can make the user reorient.

**Treatment:** Track navigation direction explicitly. Forward content translates about 12–16 points toward its destination over 200–240 ms; back reverses it. Keep toolbar, footer, and the active drink identity stable. Do not slide the whole page a screen-width. Revealing With a tweak expands its existing field in 180–220 ms, preserving the chosen pill and current scroll context. Do not automatically focus the keyboard until the field is activated. Dismiss editing keyboard before a step handoff so it does not compete with the page transition.

**Trigger and response:** Continue/back or the existing contextual choice. Selection state updates first. Reduce Motion uses an approximately 100 ms crossfade or direct change. Avoid global implicit animation on the entire draft, which could animate text entry and unrelated updates.

**Entry points:** LogASipV3ProductionViews move/moveBack/moveHome/stepTransition, Home setup and optional reveals. Evidence 10–18, 22–24; direction weakness confirmed in source.

### R6 — Give a saved sip a concise, truthful receipt

**Priority:** P1, first pass. **Effort:** M, potentially 2–3 days across active routes. **Impact:** Very high emotional payoff and certainty.

**Weakness:** Home V4 opens detail with understated local/sync status; other source paths have a static receipt, large celebration card, or older saved screen. This is inconsistent acknowledgment, not a complete lack of success UI.

**Treatment:** Keep current destinations. At a durable private save, the existing CTA becomes a check with Saved privately; one success haptic fires. Carry the drink title/cover into canonical detail and display a concise receipt at its top, with Saved on this device · Sync pending when appropriate. For a finished multi-step sip, Mugsy briefly hugs his journal and nods once over 600–900 ms, then rests. Quick logs get the check and haptic without a dance. A finalized remote publication can say Posted to Friends/Everyone only after authoritative completion. A private local save never says Posted. A pending recipe change remains a separate, actionable status.

**Trigger and response:** Once per completed save transaction, after durability is confirmed. Opening the same detail again, account refresh, background retry, and re-render must not replay it. Done/View actions work immediately; no minimum display time, new mandatory screen, or added tap. Reduce Motion uses a static pleased expression and check, preserving the same success cue. Keep existing artwork/model and avoid routine confetti or indefinite celebration loops.

**Personality and encouragement:** A quick log can say Latte, remembered. If a next-time note was actually saved, the secondary line can say Your next-time note is kept. After a completed guided make, Mugsy lowers the notebook into his arms, looks toward the drink title, and makes one pleased nod before resting. The response celebrates keeping the memory, including an unrated or disappointing sip; it does not praise a high score or invent knowledge about taste. In error states he remains attentive and still, with direct recovery language.

**Entry points:** active Home save and HomeAttemptCanonicalDetailView, SipComposerView completion routing, MugshotShareHubView, MugshotCompletionCard. Evidence 18 → 19; other completion variants source-only.

### R7 — Make Favorite, Want to Try, and private-note saves feel settled

**Priority:** P1, first pass. **Effort:** M. **Impact:** High for everyday browsing and planning.

**Weakness:** Saved has optimistic state and Undo; detail has different progress/error treatment. Confirmation can feel detached from the item. Removing a filtered item needs continuity.

**Treatment:** Toggle the heart/bookmark immediately. The selected symbol settles 1 → 1.08 → 1 in about 180 ms, with one soft/selection cue. Keep the row in place while its existing Undo opportunity is available, then collapse just that row in 180 ms without moving the scroll anchor. Preserve rollback on failure and show the error next to the initiating item. Saving a private note shows a check and Saved privately · Added to Want to Try when that side effect occurs; no full-screen celebration.

**Trigger and response:** User changes relationship or saves note. Repeat taps on the same pending mutation remain coalesced. Undo restores the previous exact relationship. Reduce Motion uses fill/check changes only. Preserve existing privacy and remote-authority contracts.

**Entry points:** SavedCafeLibraryView mutation/feedback, cafe detail utilities/private note, existing mutation coordinator. Evidence 01–02 and source.

### R8 — Connect a map pin to the cafe it opens

**Priority:** P2. **Effort:** M. **Impact:** Medium–high sense of spatial continuity.

**Weakness:** Pin, sheet, and save interaction feel like separate components. Dense-map motion would add noise.

**Treatment:** On a new pin selection, draw a short halo and increase only that pin by roughly 8% for 160–200 ms while the existing native cafe sheet presents. Preserve its geographic coordinate and rating/source identity. Give one light selection cue on a changed selected cafe, never on map pan, zoom, cluster recomputation, or repeated selection. Keep the selected cafe name stable while details refresh. Native dismissal returns to the same map camera.

**Entry points:** MapTabView, AdaptiveMapClustering, canonical cafe route. Evidence 08 → 02. Protect clustering, camera, and source attribution; this is a navigation-integration change, not a cosmetic-only check.

### R9 — Make optional reflection build naturally under the user's hand

**Priority:** P1, first pass for rating/criteria/tweak; remainder P2. **Effort:** M. **Impact:** High ease and personality during reflection.

**Weakness:** A criterion can appear far below the suggestion row; repeated coaching blocks compete with rating. Optional field reveals do little to explain the addition.

**Treatment:** A tapped suggestion changes to a selected check immediately; its criterion row expands in 180–220 ms. Preserve scroll position, nudging just enough to reveal the new row if needed and only when the person is not typing. VoiceOver focus moves to the inserted criterion deliberately. Pin/importance use small localized state changes. Mugsy's nudge responds once to an explicit tap with a short gaze/nod and the existing prompt, then stays still. No random praise, generated tasting claims, or extra reflection questions.

**Entry points:** shared criterion row/editor, existing Mugsy coach, With a tweak. Evidence 15–17, 22–23.

### R10 — Polish photo handling and making without interrupting either

**Priority:** P2, except quick row feedback can join first pass. **Effort:** M–L. **Impact:** Medium–high perceived craft in richer sessions.

**Weakness:** Photo tile, cover badge, setup changes, timer state, and As planned use different feedback patterns. Their work should remain fast.

**Treatment:** An accepted photo fades into a reserved thumbnail slot in 120 ms. On cover selection, move the cover badge with a 160 ms crossfade and one selection tick; avoid bouncing the entire strip. Reordering retains native drag feedback and stable item identity. On Start/Stop timer, update the button and timer state immediately with one soft cue; keep digits monospaced. On As planned, crossfade Unknown to the actual value and a check in 120–160 ms. The explicit confirmation is the only trigger that copies a target into actuals. Completing Make gets one small check/soft cue, reserving success acknowledgment for saving the memory.

**Entry points:** SipComposerView media handling, LogASipV3ProductionViews, HomeSipV4ActualsView. Evidence 11–14, 20, 24. Camera and drag/reorder require targeted runtime acceptance; no new media behavior or preparation requirements.

### R11 — Give the existing layouts a coherent hierarchy

**Priority:** P1 targeted first pass; P2 broad application. **Effort:** M. **Impact:** High visual finish without changing navigation.

**Weakness:** Saved's controls consume substantial first-screen space; Feed header is crowded; profile stat labels truncate; repeated card treatments and small captions vary. Reflection has more supporting emphasis than the primary score needs.

**Treatment:** Keep existing destinations and controls. Use one stable header treatment with a clear display title, secondary context, and consistently aligned 44-point utility hit areas. In Saved tighten gaps between the two existing segment rows, search, and sort/density into a clear control group; keep one natural 16–24-point separation before cards. Resolve titles/metadata/action baselines with existing 4/8/12/16/24/32 spacing tokens. Keep serif for memory/headline moments, sans for actions and data, monospaced digits where numbers change. Reduce the coaching block's vertical emphasis without removing its explicit interaction. Fix statistics with adaptive widths/wrapping, not smaller text. Confirm first/last rows remain reachable above the bottom bar.

**Entry points:** DesignSystem headers, FeedTabView, SavedCafeLibraryView, ProfileTabView/ProfileJournalView, composer surfaces. Evidence 01, 03, 05–06, 15, 23, 29.

### R12 — Give loading, empty, offline, and failure distinct identities

**Priority:** P0 for misleading states; P1 first pass. **Effort:** M. **Impact:** Very high trust; medium delight.

**Weakness:** Saved failure without cache shows a welcoming empty state; loading shows a zero count. Recovery copy mentions post IDs/local cleanup. Small status actions are cramped.

**Treatment:** Use the existing data states to render mutually exclusive presentations. Initial loading: stable skeletons, count hidden or Loading cafes. Known empty: friendly Mugsy, one useful primary action, quiet optional secondary action. Failure without cache: Couldn't load your cafes, compact calm Mugsy, Try again; never No favorites yet. Offline cache: keep cards and position, compact offline status. Success after retry: crossfade status away in 120 ms, with no celebration. Public post finalized but local cleanup unfinished: Posted · finishing on this device; retain Finish and Review. Unfinished upload: Saved here · Upload needs attention; never imply it is published. Pending sync and recipe update errors remain separate from loss of the private sip. Match Find me instruction to its actual button label.

**Trigger and response:** Changes in verified load/save state. No fake percentages, artificial delays, shimmers, repeating warning vibrations, or transitions that move the list on every refresh. Keep errors available until resolved/dismissed; do not auto-expire an actionable error. Maintain protected retry identity and access-control boundaries.

**Entry points:** SavedCafeLibraryView state rendering, MugshotExperienceState, AutomaticSipRecoveryBanner, cafe search/Map status. Evidence 21, 25–28, 31.

### R13 — Acknowledge smaller completed work where it happened

**Priority:** P2; edit receipt can join first pass. **Effort:** M. **Impact:** Medium, broad consistency.

**Weakness:** Edit success dismisses the editor; social request/invite/share and list changes use mixed busy/success patterns. A dismissed sheet can leave uncertainty.

**Treatment:** Successful Edit Sip returns to the existing detail and briefly shows Changes saved with one check/soft success cue. Accept request changes that row to Friends with a short check settle only after confirmation; a failed request retains retry. List membership shows its checked state and saved indication in the same sheet. Share preparation says Preparing share → Ready; use the native share-sheet completion result accurately, and never say Sent because a sheet closed. Read all updates its badge/count without celebration.

**Trigger and response:** The actual corresponding operation completes, once; do not use a common success toast for unrelated operations. Preserve local/remote distinctions and explicit external-audience consent. Reduced motion uses static confirmations. Real social/list/share transactions remain acceptance gaps.

**Entry points:** EditSipView and parent destination, PeopleDiscoveryHubView, ActivityCenterView, shared lists, MugshotShareHubView. Evidence 32–33 plus source.

### R14 — Make accessibility and lifecycle part of the feedback contract

**Priority:** P0/P1, required for every first-pass item. **Effort:** M shared work, with additional acceptance time. **Impact:** Essential reliability and comfort.

**Weakness:** Good localized Reduce Motion and large-text patterns coexist with unguarded shared press/selection animations and fixed labels. Generic completion's haptic is tied to its visual branch. Long Undo/error messages need assistive-technology consideration.

**Treatment:** Read the effective system/DEBUG Reduce Motion value in shared controls; replace travel/scale/bounce with state changes or a short opacity fade. Keep tactile preferences independent. Keep all necessary information in text, icon, and accessible value, never haptic/color alone. Aim for 44 × 44-point independent touch areas on custom controls, including recovery close and criterion accessories, without overlapping. Announce meaningful completion/failure once; move focus to the destination heading or changed item, and avoid announcing each animated value. Preserve existing Undo, allow sufficient time for assistive use, and keep critical errors persistent. Stop one-shot tasks when views disappear, the app becomes inactive, or account/session identity changes. Keep offscreen tabs out of VoiceOver focus.

**Entry points:** shared motion/haptic system, controls, completion card, recovery/status components, canonical navigation. Evidence 02, 19, 29, 31 and source. Actual VoiceOver/Switch Control, Reduce Transparency/Increase Contrast, and device tactile feel need focused acceptance; no compliance certification is claimed.

### R15 — Bring onboarding's authored personality into native, accessible presentation

**Priority:** P2, deeper improvement. **Effort:** L. **Impact:** High first impression and accessibility; lower frequency than the core loop.

**Weakness:** The approved introduction is full-screen artwork with native invisible hit regions. Its text cannot scale independently; repeated raster buttons cannot show native pressed states. Page 6's Journal picture depicts an older tab arrangement than current Journal.

**Treatment:** Preserve the approved imagery and sequence. Separate artwork from native title, body, count, and actual visible controls in the same visual arrangement. Use a 160–220 ms content crossfade with stable Continue/Skip positions; respond to presses immediately. Keep Skip and account/guest exits available throughout. Update depicted app UI to current labels when regenerating the approved art. Do not add onboarding steps or an animation that must finish before Continue works. Under Reduce Motion, change content directly or with a brief fade. Do not remove/reorder the nine panels as part of polish without a separate product decision.

**Entry points:** MugshotFirstLaunchAppScene and MugshotOnboardingView. Evidence eight retained panels in gallery 30; page 7 source-only. No account creation or sign-in performed.

### R16 — Keep account, privacy, permission, and destructive flows quietly precise

**Priority:** P2. **Effort:** M. **Impact:** Medium ease and high trust.

**Weakness:** Auth entry's illustration and preview push form fields low; settings/status layouts vary and can detach an error from its action. These surfaces need restraint more than personality.

**Treatment:** When email entry starts, let the form scroll into focus while the welcoming hero stays still. Reserve space for inline validation beneath the relevant field; show a stable busy button and preserve typed data on failure. Save a preference with adjacent Saving/Updated state and native switch behavior; restore the previous value on error. Keep permission explanations clear and let iOS own the prompt. Preserve explicit destructive confirmations with precise action names and no celebratory character.

**Entry points:** AuthEntryView, RequiredProfileSetupView, SettingsView, Phase6SettingsViews, NotificationSettingsView. Evidence 00, 07 plus source. No new permissions, settings, data collection, or access changes.

## Recommended cohesive first pass

**Recommendation:** polish the entire existing discover → remember → return loop to one standard. Start with the active Home V4 and Cafe paths; then make the same primitives consistent in Saved, Feed, Journal, and detail. Do not begin with onboarding artwork replacement or an isolated large mascot celebration.

| Order | Work package | Includes | What the user notices | Approximate effort |
| --- | --- | --- | --- | --- |
| 1 | Truth and legibility | R1; shared-control portion of R2; false-empty and zero-loading corrections from R12 | Unrated/unknown/private states are unambiguous; actions are readable | 1.5–2 days |
| 2 | Immediate response | R3–R4; core criterion/tweak parts of R9; shared R14 | Ratings, choices, hearts, and buttons feel crisp and quiet | 2–3 days |
| 3 | Continuity and acknowledgment | R5–R7; edit receipt from R13 | Forward/back make sense; a saved memory feels complete; Saved actions remain recoverable | 3–4 days |
| 4 | Visible refinement and integrated acceptance | Targeted R11; remaining R12/R14 | Headers, status, loading, and recovery feel designed together | 1.5–2 days |

**Planning range:** roughly **8–11 focused engineering days**, including a bounded integrated Simulator acceptance session, with shared primitives reducing overlap. This is an estimate, not a schedule or promise. Device feel/performance evaluation is a separate owner-promoted pass. Deeper map continuity, media choreography, full onboarding reconstruction, and every supporting account/social surface follow after the core pass. No new backend contracts are anticipated; any newly discovered contract work must be scoped explicitly.

### Quick wins to do first

- Correct private Review/Share language, optional photo language, required-caption hint, Find me mismatch, and Not rated presentation.
- Label target-only Home summaries as planned without changing what is persisted.
- Use accessible sage roles for enabled controls and supporting text.
- Remove false empty and zero-loading claims; retain cached content.
- Fix profile/People truncation and honor Reduce Motion in shared press styles.
- Remove duplicate routine reaction success cues and connect the active half-star control to Rating haptics.

### Deliberately later

- Full native onboarding text/control extraction from approved artwork.
- Map pin-to-sheet motion and richer photo/reorder choreography.
- Broad supporting-screen type/status consolidation after the core loop establishes the pattern.
- Any new feature, reward, streak, point, leaderboard, achievement, push campaign, or extra required reflection step. Existing counts are not expanded into new gamification.

## Feedback and performance specification

These are proposed starting values to tune in context, not frame-time measurements from this audit.

| Interaction | Proposed budget | Reduce Motion / lifecycle behavior |
| --- | --- | --- |
| Tap/selection acknowledgment | Next state update; aim for visible response within 100 ms | Tint/check, no movement |
| Press/release | 80 ms press, 140–180 ms release | No scale |
| Rating/relationship change | 100–180 ms localized settle | Direct fill/value change or short fade |
| Insert/reveal | 180–220 ms, no staggered cascade | Direct reveal or 100 ms fade |
| Step forward/back | 200–240 ms, 12–16-point travel | Direct update/short fade |
| Save receipt | 600–900 ms maximum expression; actions enabled immediately | Static expression/check; haptic independent |
| Loading | Only while genuinely loading; retain cached content | Static placeholders, no shimmer |

Implementation rules: animate transforms/opacity on small elements, retain stable item IDs, decode media off the main thread through existing pipelines, avoid animating entire lazy lists or observable draft graphs, and never add a polling timer just to decorate a screen. Reuse the existing event-driven Mugsy wrapper and pause logic. Avoid adding blur, particle systems, new infinite timelines, or custom gestures where native controls suffice. Measure a concrete regression if one appears; this audit did not collect frame, CPU, energy, or memory traces.

## Implementation verification plan

| Change | Minimum repository tier and evidence |
| --- | --- |
| Copy, spacing, palette, isolated press treatment | Tier 1: diff, fast static gate, one generic Debug compile; stop when passed |
| Rating feedback ownership, one-shot save receipt, unset/target display mapping | Tier 2 where local: Tier 1 plus one focused deterministic test for changed logic, including no replay/duplicate cue and no target-to-actual promotion |
| Step direction/focus, route transitions, filter-removal Undo, load/error presentation, shared completion routing | Tier 3: full-static plus focused existing/pure tests for affected state contracts; prepare runtime-only cases before the single acceptance session |
| Combined cross-feature polish candidate | Tier 4 consolidated acceptance after deterministic checks pass; one build/install/launch, prepared matrix, representative screenshots and failures; no alternating fix/launch discovery loop |

Core acceptance matrix: Cafe and Home quick/guided paths; back/edit/resume; unrated and half-star; optional photo and cover choice; As planned versus unknown; With a tweak; private save versus pending sync versus posted; repeated save/event handling; Favorite/Want to Try/Undo/failure; empty/loading/cached-offline/no-cache failure; default and accessibility text sizes; Reduce Motion; actual VoiceOver focus/value/announcements; interrupted/background/disappeared receipt; no completion replay when reopening detail.

No changes to authentication, privacy, source attribution, audience, optionality, recipe/version ownership, post retry identity, or backend data contracts are intended. If implementation touches those contracts, expand focused tests for that concrete risk. Respect the separate manual TestFlight gate; no archive/export/upload or version bump is part of this plan.

## Checks performed for this audit

- Current Debug Simulator build passed once (XcodeBuildMCP, 130.4 seconds); built solely to inspect the current app, not as verification of a future polish patch.
- Current source and native UI snapshots inspected; accepted screenshots saved and reopened. One local private Home attempt was created only in the isolated Simulator fixture environment.
- Shared color-token contrast calculated from sRGB values. Transparent/material/photo-composited states need their own final checks.
- Documentation changes passed Tier 0: scoped diff inspection, ./scripts/check-documentation.sh, and git diff --check. The report's local links, 16 recommendation entries, 41 unique evidence files, and ASCII cafe spelling were checked. The screenshot gallery was opened and its rendered layout inspected in the in-app browser.
- No Release build, full test suite, device acceptance, performance trace, production write, archive, upload, or TestFlight action.

## Reference guidance

The proposed response hierarchy and restrained tactile cues follow [Apple's motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion) and [haptic guidance](https://developer.apple.com/design/human-interface-guidelines/playing-haptics). Preserve accessibility alternatives per [Apple's accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility). Color calculations use the contrast definition in [WCAG 2.2](https://www.w3.org/TR/WCAG22/#contrast-minimum) as a legibility benchmark; this is not an app-wide conformance claim. All Mugshot observations above come from the current captured UI or current source, not comparator screenshots or old audits.
