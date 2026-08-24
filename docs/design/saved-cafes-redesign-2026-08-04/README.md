# Saved Cafes Redesign Package

This directory defines the deterministic, light-only PNG handoff for the selected Saved cafes redesign. The machine-readable file inventory is in [`manifest.json`](manifest.json), and all fixture, composition, and evidence mappings come from [`src/design/data.ts`](src/design/data.ts).

## Selected combined target

[`concepts/00-locked-combined-direction.png`](concepts/00-locked-combined-direction.png) is the visual source of truth. The selected target combines Option 1's journal-first native bottom-sheet structure with Option 2's compact horizontal search bar.

The complete board set must preserve these decisions:

- The medium detail sheet orders cafe identity, a full-width `Log a Sip` action, four labeled state actions, then `Your Mugshot`.
- Saved remains list-based. The existing Map tab is the sole map surface and retains Favorites, Want to Try, Visited, Friends, and discovery filters.
- The selected map composition demonstrates the unified cafe-detail sheet inside the existing Map tab; it is not a duplicate Saved Map implementation.
- Comfortable cafe cards are the default; compact rows are a supported density.
- Appearance is light only. Do not create dark-mode variants or generated UI copy.
- Authorized Mugshot media becomes the cafe photo when available. Until future owner profiles can provide media, every other cafe uses a branded no-photo treatment; external place-photo providers are out of scope.
- Comfortable cards expose Favorite, Want to Try, and Log a Sip. Compact rows keep the two saved-state controls visible and move Log a Sip into overflow.

## Checkpoint review

The four approved checkpoint frames are rendered and the package is paused for review:

- `CF-01` Favorites populated
- `CF-03` authoritative All Cafes union
- `CF-12` existing Map tab with the shared compact cafe-detail sheet
- `CD-03` expanded cafe detail

No remaining screen, component board, or specification board will be exported until these checkpoints are approved. See `design-qa.md` for the browser-rendered comparison and verification record.

## Locked package

The approved package contains 48 PNG files: 36 screens, six component boards, and six specification boards.

| Deliverable | Count | Dimensions | Directory |
| --- | ---: | ---: | --- |
| Screens | 36 | 1206 × 2622 | `screens/` |
| Component boards | 6 | 2400 × 1600 | `boards/components/` |
| Specification boards | 6 | 2400 × 1600 | `boards/specifications/` |

The 36 distinct screens are CF × 12, CD × 8, ST × 6, RS × 6, and AX × 4. `CD-01` is a compatibility alias for `CF-12` (`screens/CF-12-map-tab-saved-cafe-detail.png`) and is not a second screen or an additional PNG. Lower-frequency variants are consolidated onto component boards rather than repeated as full-screen compositions.

`manifest.json` is authoritative for every filename. Each screen entry maps its output file to the exact `fixture`, `composition`, and `evidence` values in `src/design/data.ts`. The CP and SP entries map the six component-board files and six specification-board files to their source definitions.

## Protected Lists boundary

Lists remain visually and behaviorally unchanged. List creation, collaboration, existing list maps, editing, ownership transfer, and deletion are outside this redesign and must not regress.

Only the cafe-membership entry sheet and its batch data contract are in scope. `CD-11`, `CP-05`, and `SP-06` document that narrow boundary, including selected memberships, permissions, staged changes, and partial-failure recovery. They must reuse the established Lists system rather than redesigning it.

## Source and implementation boundaries

- `AGENTS.md` defines the locked visual and runtime contract.
- `src/design/data.ts` defines the deterministic fixture time, screen inventory, board inventory, compositions, fixtures, and audit evidence.
- `concepts/00-locked-combined-direction.png` defines layout, density, typography, color, component anatomy, and hierarchy.
- This package is a design artifact only. It does not authorize production-app, protected-runtime, or user-research changes.

All user-facing copy and product documentation must spell `cafe` and `cafes` without an accented e.
