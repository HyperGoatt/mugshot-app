---
document_type: historical
status: checkpoint
date: 2026-11-09
---

# Home persona walkthrough and composer correction

Documentation impact: product behavior and local draft eligibility. Update
the Home recipe implementation, product/verification status, local data flow
and changelog. No backend contract or release configuration change is needed.

1. Use the isolated guest QA app. Walk Saved and Journal into the same Home
   library, then try recipes, beans, gear, preferences and the Home composer
   with beginner and experienced brewer goals. Record what happened separately
   from proposed design changes.
2. Reproduce the setup jump. On the previous candidate the title shifts inward
   and down when Home is selected, the Cafe icon changes, and the pills belong
   to different scroll layouts. Check the selection, each panel and its scroll
   behavior with an actual UI regression test.
3. Give setup one header, autosave cue, draft entry and context selector above
   the changing content. Keep the selected pill accessible and the same size
   and position. Keep shared sip inputs when changing context; place-specific
   inputs must stay out of an unrelated sip. Preserve the protected save lock.
4. Verify an early Elsewhere draft can restore after relaunch even when the
   setting is its only entered field. Do not manufacture drafts from context
   navigation or the automatic Home location label.
5. Recheck the affected setup, draft and Home journeys on Simulator and run the
   relevant scoped storage contracts. Preserve the existing delivery holds.
