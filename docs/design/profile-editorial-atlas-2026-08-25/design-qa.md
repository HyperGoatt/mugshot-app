---
document_type: historical
status: locally-verified
date: 2026-08-25
---

# Editorial Atlas design QA

## Comparison method

The approved reference and deterministic Simulator capture were evaluated at
the same 368-by-800 viewport. The final comparison board places the approved
reference on the left and the shipping SwiftUI implementation on the right:

- [`approved-reference.png`](approved-reference.png)
- [`simulator-profile-top-final.jpg`](simulator-profile-top-final.jpg)
- [`design-qa-comparison-final.jpg`](design-qa-comparison-final.jpg)
- [`simulator-profile-map-final.jpg`](simulator-profile-map-final.jpg)

## Accepted result

- The photographic hero, overlapping avatar, and foam-white floating Friends,
  Sips, and Cafes statistics dock preserve the approved hierarchy.
- Identity, actions, all three Favorite Spots, the four-tab rail, and 3:4
  Mugshot thumbnails fit the intended visual rhythm without Profile Highlight.
- Favorite Spots remain visual and compact while keeping cafe names and the
  owner's descriptor legible.
- Mugshots, cafes, map, and tagged tabs use distinct Mugshot-native system
  iconography and the approved left-to-right order.
- The map tab reuses the production MapKit surface, rating pins, clustering,
  location control, cafe count, and ratings legend. It does not introduce the
  rejected dotted route treatment or a replacement map style.

Native status/navigation chrome, production typography, and production design
tokens intentionally replace the illustrative chrome in the approved image.
These are implementation-level differences, not product-design deviations.

## Evidence boundary

The deterministic shared profile and each tab were built, installed, launched,
and inspected on the iPhone 17 Pro Simulator. A separate owner fixture verified
Edit profile, profile actions, Favorite Spots editing, every tagged-grid action,
and the Hide from profile / Remove my tag choice. Focused profile model tests
and the hermetic database contract check passed. This evidence is
Simulator-accepted; it does not claim production configuration,
physical-device interaction, or TestFlight acceptance. Physical testing is
intentionally deferred until the owner explicitly promotes a candidate and is
not a completion gate here.
