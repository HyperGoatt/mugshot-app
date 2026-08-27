---
document_type: historical
status: approved-reference
date: 2026-08-25
---

# Editorial Atlas profile reference

This directory preserves the approved image target for the 2026-08-25 Mugshot
profile redesign. It combines the clear hierarchy of the first exploration with
the visual richness of the third. The approved implementation rules are:

- a photographic hero with a foam-white floating Friends, Sips, and Cafes dock;
- profile identity and actions below the hero, with Profile Highlight removed;
- up to three photographic Favorite Spots with a cafe name and owner-authored
  descriptor;
- public Mugshots, public cafes, the profile owner's exploration map, and public
  tagged Mugshots in that order;
- the production Mugshot MapKit surface, pins, clustering, legend, and location
  control, with no dotted route lines or replacement map treatment;
- 3:4 portrait Mugshot thumbnails and a two-column visual cafe grid;
- owner controls to hide a tagged Mugshot from the profile or remove the tag;
- no Friends-only or private Mugshot in any of the four public tabs.

The PNG is design evidence, not a shipping runtime asset. Production UI uses
Mugshot's existing asset catalog, remote media pipeline, design tokens, MapKit
components, and system icon library.

The final same-viewport implementation comparison and its evidence boundary are
recorded in [`design-qa.md`](design-qa.md).
