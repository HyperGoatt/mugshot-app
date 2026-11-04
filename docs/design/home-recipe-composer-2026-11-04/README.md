---
document_type: historical
status: implementation-in-progress
---

# Recipe capture and drink composition — November 4, 2026

Current implementation and acceptance: [Home recipes](../../HOME_RECIPES_IMPLEMENTATION.md).
This native review package changes product presentation and draft composition,
reusing existing account ownership, immutable recipe links, persistence and
publication contracts. No Supabase or model/quota change is planned.

## Sources and observed problem

- [Original interview, Round 4](../../MUGSHOT_V3_PRODUCT_INTERVIEW.md#round-4-of-8-cafe-home-and-everywhere-else):
  a syrup can be a reusable recipe, casual depth stays optional, gear is entered
  once, versions stay behind the scenes, and Home finishes with the common sip
  reflection.
- [Accepted September Home V4 interview/read-back](../../product-research/home-sip-v4/README.md):
  save syrup and foam separately, combine with a preferred base and milk, keep
  usage amounts in the parent drink, preserve the parent when inspecting a part,
  and never turn the parts into automatic journal entries.
- Owner-requested read-only phone inspection: the blueberry syrup has five
  ingredients, ten steps, source and creator credit, but remains a generic
  Preparation / Other. The Add screen exposes a plain multi-field Form. Linking
  a recipe requires the full editor and an implementation-oriented version picker.
  The private phone backup stays outside the repository.

## Native direction

1. A source-first capture page uses the Mugshot cream, espresso and accessible
   sage palette, large serif identity, readable source input and compact media
   choices. Import feeds an editable recipe preview; credit and advanced fields
   are secondary. A simple Brew / Component / Drink choice describes its use.
2. A syrup or brew offers **Use in a drink**. It opens an editable mix with a
   coffee/tea/matcha base, milk and the exact saved component. Amounts are optional
   and belong to this drink. The syrup batch and source never change.
3. **Build a drink** is directly available from the recipe book. Add saved parts
   by name, inspect one and return, or add a plain ingredient. Version IDs remain
   internal; no repeated template wizard or new inventory setup is required.
4. Save a reusable recipe explicitly, then use the existing optional guidance →
   capture → shared reflection → review journey. AI is optional throughout.

The current task authorizes implementing this extension of the accepted Home V4
direction. Native captures and focused fixture journeys will make the result
reviewable before delivery to the owner app. Existing owner recipes are not
reclassified, edited or used for synthetic saves.

## ECC checkpoints

- `dad56de`: intended missing-API RED for recipe use/composition.
- `71d967b`: 9/9 native composition tests pass.
- `e436e03`: native UI RED at the absent source-first capture heading.
- The imported-drink boundary then runs as a full 10-case native suite: 9 pass,
  one fails because replacing a guessed first-part base deletes the leading milk
  ingredient. Base replacement must identify the base, preserving unrelated parts.
- The first UI iteration passes 17/18 checks; its remaining preview assertion
  expects unnumbered text while the existing detail renders a numbered step.
  Screenshot review also exposes a real 15 → 1 input issue. The corrected
  assertion and focused RED run confirm truncated syrup entry and a needless
  version when reselecting an unchanged base. A separate 150.5 entry case passes.
- `fdf6f25`: RED checkpoint for those two confirmed failures. The fix retains
  focused numeric text while editing and leaves an unchanged base intact.
  `/tmp/mugshot-recipe-composer-green2.xcresult` passes 16/16: 12 native cases
  and 4 UI cases, including the complete component → latte → linked preview →
  guidance → shared review journey. Broader delivery checks follow below.

## Interaction references

Apple's [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data)
and [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)
inform paste support, reuse of existing choices, scoped part selection and
preservation of the parent task. These references guide the design; the native
runtime and accessibility checks establish this implementation's behavior.
