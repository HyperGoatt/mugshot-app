# Mugshot V3 Product Direction

**Status:** Locked source of truth for V3 design and alpha implementation

This folder preserves the approved Mugshot V3 product direction so future design and engineering work does not depend on a single Codex conversation, a temporary attachment, or a Figma file.

## Start here

- [Complete eight-round product interview](../../MUGSHOT_V3_PRODUCT_INTERVIEW.md) - the durable decision record, including Joe's answers, agreed interpretations, alpha gates, safety boundaries, and unresolved hypotheses.
- [Approved five-screen visual direction](references/approved-v3-five-screen-direction.png) - the primary visual reference for setup, sip reflection, publishing, and the non-radar Taste Passport.
- [Cafe reflection direction](references/cafe-reflection-direction.png) - the approved companion reference for the cafe reflection surface and the alternate scoring/passport treatments that informed the final direction.

The interview is authoritative for product behavior. The images are authoritative for the current visual direction. If they appear to conflict, preserve the interview decision and record any proposed visual change before implementing it.

## Locked five-screen flow

1. **Log a Sip setup** - choose Cafe, Home, or Elsewhere; add photos or the deliberate Mugsy placeholder; choose a cover; name the drink; and identify the cafe or setting when relevant.
2. **How was the sip?** - optional private journal note, user-owned sip score, optional evaluative criteria, human-language importance, pinned or previous criteria, Mugsy thinking prompts, and flavor exploration.
3. **Context reflection** - Cafe reflects the cafe once per visit; Home supports recipe and repeatability evidence without another rating; Elsewhere supports a named setting with optional reflection and score.
4. **Publish Mugshot** - review the memory, write the required caption, confirm scores, choose Private/Friends/Everyone, separately control raw-note visibility, invite friends, choose the cover, and publish or retain a ready draft.
5. **Taste Passport** - show a private, evidence-backed taste identity with confidence language, supporting memories, criteria, and a clear "Why am I seeing this?" explanation. Do not use the rejected radar/web visualization.

## Free visual iteration workflow

Use the DEBUG-only SwiftUI UI Lab under `testMugshot/Views/Developer/LogASipV3Lab/` as the working visual prototype. Keep it isolated from production persistence, networking, camera, authentication, and publishing behavior.

The preferred loop is:

1. Make a focused change in the UI Lab using existing Mugshot tokens and components.
2. Review the affected state in Xcode Preview at the target iPhone size.
3. Run the UI Lab in Simulator when interaction or the complete five-screen journey matters.
4. Compare the rendered state against the approved images above before accepting the change.
5. Only map a validated direction into production code after explicit approval.

This workflow is the free replacement for using Figma MCP as the primary iteration surface. Figma remains optional for manual design work and handoff. Use Source Serif 4 in Figma; use the iOS system serif in SwiftUI code.

## Current rendered evidence

- [Setup](ui-lab/01-setup.jpg)
- [Sip reflection](ui-lab/02-sip.jpg)
- [Cafe reflection](ui-lab/03-cafe.jpg)
- [Publish review](ui-lab/04-publish.jpg)
- [Taste Passport](ui-lab/05-passport.jpg)
- [Design QA record](../../../design-qa.md)

These captures are fixture-driven Simulator evidence, not production implementation screenshots. They should be refreshed when an approved visual direction changes.

## Change control

Do not silently replace a locked V3 decision. When alpha evidence changes the direction, update the interview archive with the date, evidence, decision owner, prior rule, and approved new rule, then update these references and the UI Lab together.
