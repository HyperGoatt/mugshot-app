---
document_type: living
status: current
last_verified: 2026-11-24
---

# Marketing-site brand alignment

The [Mugshot brand kit](README.md) is the identity authority. The marketing site
must consume that contract. This is an implementation handoff and source audit;
the live marketing site has not been migrated by this change.

## Audited evidence

Local repository: `mugshot-marketing`, commit `924cbc2` (November 24 inspection).
This is current local source evidence, not a visual certification of production.
No site palette, font, image, or copy was imported into the brand kit as authority.

| Source | Observed difference | Required replacement |
| --- | --- | --- |
| `src/styles/home.css` | Campaign `--pistachio: #abff44`, `--peach: #91dbda`, `--evergreen: #08241a` | Cream canvas; native mint, sage-text, espresso, and roast tokens. Drink photography supplies vivid color. |
| `src/styles/home.css` | Campaign headings use sans, weight 800, tracking -0.065em | Regular serif display, app-derived tracking and a responsive web scale. |
| `src/styles/global.css` | Separate cream `#f8f3ea`, surface `#fffcf7`, ink `#16221b`, and forest `#143d31` | Import generated tokens.css and bind all surface/text roles to it. |
| `src/styles/global.css` | Instrument Serif and Manrope Variable stacks | App-derived system serif/sans stacks. No external font files in the kit. |
| `src/styles/global.css` | Independent 360/760 ms movement and broad 80 px shadow | Native base motion and shadow vocabulary, translated for CSS; respect reduced motion. |
| `src/styles/product-preview.css` | Separate stage, paper, ink, sage, and line values | One semantic token contract; actual source artwork or clearly labeled reference compositions. |

## Integration order

1. Pin kit **1.1.0**, its source commit, and asset hashes in the marketing repo.
   Consume the reviewed source directory or its verified package. Do not create
   another hand-maintained brand spec. A downstream DESIGN.md should point here.
2. Import tokens.css once and replace global and campaign color aliases. Delete
   duplicate palette definitions instead of leaving a later override.
3. Restore the serif/sans hierarchy, readable line heights, and cream page canvas.
   Use the five new photographic-style scenes and unchanged icon from assets.json.
   Use the 18 reviewed Mugsy cutouts as supplied. Future poses must follow the
   [immutable identity contract](identity/README.md); never use a generated pose
   as the next identity reference or redraw Mugsy downstream.
4. Recompose each page using the app's hierarchy. Use the
   [website reference](templates/landing.html) for visual alignment, then adapt
   the actual site content and navigation to each page's purpose.
5. Use sage-text/white for primary actions and espresso on mint. Keep essential
   field outlines visible. Use persistent labels, focus states, semantic links,
   keyboard access, responsive text, and reduced motion.
6. Review every factual claim against actual current release evidence. Keep
   native audience meanings exact and private notes out of marketing examples.
7. Record adoption only after the whole site passes the checks below. Preserve
   existing routes, legal content, SEO metadata, and working destinations unless
   the separately reviewed site change intentionally changes them.

## Consumer example

```css
@import './vendor/mugshot-brand/tokens.css';

body {
  background: var(--mugshot-canvas);
  color: var(--mugshot-text);
  font-family: var(--mugshot-font-body);
}

h1, h2 {
  font-family: var(--mugshot-font-display);
  font-weight: 400;
  letter-spacing: var(--mugshot-display-tracking);
}

.primary-action {
  background: var(--mugshot-action);
  color: var(--mugshot-action-text);
  border-radius: var(--mugshot-radius-pill);
}
```

The import path is an integration example, not an assertion that the marketing
repository currently vendors this directory. Native point values translate to
CSS px for primitive spacing; web layout remains responsive.

## Acceptance checklist

- Global, campaign, guide, privacy, beta, and product-preview routes all consume
  the same tokens. No independent lime, cyan, forest, or altered neutral palette
  remains in brand surfaces.
- Headings use regular serif. Body, controls, and metadata use system sans.
- Hero imagery and character use can be traced to assets.json and exact hashes.
- Synthetic brand scenes are not represented as a named real venue, customer
  photograph, or app screenshot. Retired baked onboarding panels are not reused.
- Original icon padding, character proportions, glasses, and source orientation
  remain intact. No invented mono, inverse, or vector mark is introduced.
- Mobile and desktop layouts preserve the photo-first hierarchy without clipping,
  tiny text, missing controls, or horizontal page overflow.
- All text and essential controls meet their required contrast in context;
  focus, text growth, keyboard use, and reduced motion work.
- CTAs have verified real destinations and honest availability. No invented
  user counts, reviews, awards, pricing, or App Store claims appear.
- Private/Friends/Everyone language matches current app semantics. No personal
  journal, private note, or live user account enters reference imagery.
- Navigation, legal pages, page titles, descriptions, canonical URLs, and sharing
  routes retain their intended behavior.
- The site change includes its own build/runtime checks and visual evidence.
  This brand-kit change does not substitute for that verification.

## Adoption ledger

| Surface | State | Evidence |
| --- | --- | --- |
| Native palette, spacing, icon, identity, and source language | Extracted and preserved | source-manifest.json and immutable identity contract |
| New photographic-style imagery and Mugsy poses | Integrated as native resources and kit exports | Five scenes, 18 reviewed poses, retained OpenAI generation receipts |
| Native Mugsy catalog | Implemented in source | Typed native/artwork view, production rig, and macOS offscreen previews; see VERIFICATION.md for compile evidence |
| Brand contract and local reference applications | Implemented | This versioned directory |
| Native controls | Existing styles remain | This update changes imagery and Mugsy's pose subsystem; some older controls use softer sage |
| Marketing production site | Not migrated by this change | This handoff defines the required work |
| Social / email publication | Reference only | Templates are local artifacts; no message or campaign was sent |
| Physical device / TestFlight | No new gate claimed | Source integration does not establish install or release acceptance |
