---
document_type: living
status: current
last_verified: 2026-11-24
---

# One Mugsy, every pose

Mugsy's identity is fixed. Poses and accessories expand through the single
[pose specification](mugsy-spec.json), which generates the app's typed
[MugsyCatalogPose](../../../testMugshot/Design/MugsyPoseCatalog.swift).
This subsystem belongs to the [Mugshot brand authority](../README.md).

## Immutable identity

[Mugsy-identity-master.png](Mugsy-identity-master.png) preserves the original
500 x 500 Wishlist artwork byte for byte. The native asset is
`MugsyIdentityMaster`. The original bookmark is a prop; the original sad
expression is not the emotional direction for new product illustrations.
Never replace the master with a generated pose.

The specification locks the master hash and seven native shapes: body, rim,
inner rim, handle, glasses, cheeks, and feet. The same geometry is used in every
native pose. White ceramic, glasses, proportions, thin limbs, small hands/feet,
and the handle on the image right remain permanent.

Original supporting raster poses are retained under `legacy-originals/` as
historical evidence. The five existing `MugsyNo*` / `MugsyComingSoon` asset names
now contain updated poses, preserving their existing app references.

## Controlled variables

Expression, gaze, arm articulation, knee bend, liquid state, context outfit,
and accessory are the permitted variables. Accessories stay separate from
anatomy and below the glasses. They do not recolor the ceramic or obscure the
face. Outfits remain occasional context cues.

The 18 configurations cover welcome, Want to Try, Favorites, cafe scouting,
Friends, maintenance, camera, journal, cozy ritual, celebration, map, beans,
matcha, pour-over, takeaway, tasting, guidance, and a quiet pause. New accessories
have their own code-native layer in
[MugsyExpandedAccessoryView](../../../testMugshot/Views/Components/MugsyExpandedAccessoryView.swift).
Existing scene-family selection remains deterministic and now consumes the
same typed configurations.

## Generation contract

1. Reference the immutable master in every image-generation request. Never
   recursively derive a new identity from the last generated pose.
2. Request one pose per square PNG, true transparent alpha, complete limbs and
   accessories, and generous clear margins. No scene, floor shadow, text, logo,
   checkerboard, duplicate character, or new anatomy.
3. Keep body, rim, handle, glasses, proportions, cheek positions, and palette
   fixed. Describe only the permitted pose/expression/accessory changes.
4. Record the complete prompt, input reference hash, generated source identifier,
   and named native destination in [generation receipts](../generation/).
   The built-in OpenAI tool does not expose a specific engine version.
5. Inspect the full output against the master: silhouette and ratio, glasses,
   handle side/shape, limbs, accessory, expression, shading, and clear margins.
   Hashes and alpha checks cannot prove visual identity; optical review is a
   separate gate.
6. Correct a failed asset before integration. The bean-bag pose's first output
   had an unwanted matte; a background-only image-engine correction removed it.
   That attempt is retained in its receipt, not promoted as a new identity.
7. Record the accepted PNG hash, alpha bounds, and optical review in the
   specification. An image change invalidates that acceptance.

The generated artwork is a static illustration. The native view is a separate
rendering of the same semantic pose using exact shared geometry. Pixel-identical
matching between the two media is not claimed.

## Native use

```swift
// Default: shared code-native geometry, suitable for app composition.
MugsyCatalogView(pose: .mapExplorer)

// Static, generated PNG with alpha-derived optical registration.
MugsyCatalogView(pose: .cameraCompanion, rendering: .artwork)

// Existing motion wrapper can consume the same configuration.
MugsyAnimatedView(
    configuration: MugsyCatalogPose.firstSipCelebration.configuration,
    action: .success
)
```

`MugsyCatalogView` uses the PNG's measured alpha bounds for consistent display
scale and centering. It preserves the original image bytes and leaves all
active pixels inside the presentation. Native views retain their existing rig.
Mugsy Studio includes the complete catalog with a rendering switch.

## Verification and change workflow

```sh
python3 scripts/mugsy-catalog.py --build
python3 scripts/render-mugsy-catalog.py
python3 scripts/mugsy-catalog.py --check
python3 scripts/brand-kit.py --build
python3 scripts/brand-kit.py --check
./scripts/check-documentation.sh
```

The renderer compiles the actual production SwiftUI sources and renders each
pose offscreen in a fresh macOS process. A fresh graph avoids stale export
resources between successive ImageRenderer instances. These previews are
reference evidence, not iOS runtime, device, or TestFlight acceptance.

The native app separately requires a Debug compile when Swift or resources
change. No app launch or production data is needed for this asset/catalog work.
Record physical or distribution acceptance only if actually performed.

Add a new pose by updating the specification, generating its image from the
same master, performing optical/alpha review, generating the typed catalog,
rendering its native reference, and updating the brand exports and version.
An identity change requires a separate explicit product-owner decision; adding
a pose does not authorize changing the master or the seven protected shapes.
