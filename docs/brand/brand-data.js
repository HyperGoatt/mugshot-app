/* Generated app-source contract. Works offline without fetch. */
window.MUGSHOT_BRAND = {
  "brand": {
    "name": "Mugshot",
    "version": "1.0.0",
    "last_verified": "2026-11-24",
    "source_revision": "0bece7e83a96a3f8e0167bc74ec87588e83ad1a1",
    "authority": "This directory is Mugshot's brand authority. Native app resources supply the identity; the marketing site consumes this kit. Change the kit and its affected consumers together.",
    "scope": "Brand specification and reference applications. This is not an app release, a marketing-site deployment, or evidence of feature availability in a distributed build.",
    "positioning": {
      "description": "A personal sip journal for the drink, the place, and the little moment around it.",
      "status": "Source-derived synthesis of native onboarding, not a new product claim.",
      "audience": "People who want to remember their drinks, return to favorite cafes, and choose what they share with friends.",
      "promise": "Help people remember what they enjoyed and what they want to try next.",
      "personality": [
        "Warm",
        "Observant",
        "Personal",
        "Calm",
        "Quietly playful"
      ],
      "principles": [
        {
          "title": "The moment comes first.",
          "body": "Lead with the drink and its memory. Ratings and interface details support the story."
        },
        {
          "title": "A journal at your pace.",
          "body": "Use inviting, specific language. Keep social sharing a choice and preserve audience meaning."
        },
        {
          "title": "Warmth, with room to breathe.",
          "body": "Use cream surfaces, espresso typography, gentle green accents, and generous space."
        },
        {
          "title": "Mugsy is a companion.",
          "body": "Use the existing character to guide and acknowledge. Keep his permanent identity intact."
        }
      ]
    },
    "sources": {
      "palette": "testMugshot/Design/BrandColors.swift",
      "system": "testMugshot/Design/DesignSystem.swift",
      "motion": "testMugshot/Design/MugshotMotionSystem.swift",
      "character": "testMugshot/Design/MugsyDesignSystem.swift",
      "onboarding": "testMugshot/Views/Onboarding/MugshotOnboardingView.swift",
      "authentication": "testMugshot/Views/Auth/AuthEntryView.swift",
      "character_rules": "docs/MUGSY_DESIGN_SYSTEM.md",
      "artwork_authority": "docs/MUGSY_ASSET_STATUS.md"
    },
    "color_roles": {
      "canvas": "creamWhite",
      "surface": "foamWhite",
      "surfaceQuiet": "sandBeige",
      "text": "espressoBrown",
      "textSecondary": "roastBrown",
      "action": "mugshotSageText",
      "actionText": "foamWhite",
      "accent": "mugshotMint",
      "accentText": "espressoBrown",
      "border": "mugshotLine",
      "focus": "mugshotSageText"
    },
    "color_usage": {
      "creamWhite": "Primary page canvas. The warm surface that connects app and marketing.",
      "foamWhite": "Cards, fields, and text on the accessible dark sage action color.",
      "espressoBrown": "Primary type, editorial headings, and high-contrast marks.",
      "roastBrown": "Body copy, supporting text, and readable secondary information.",
      "mugshotMint": "Accent panels and selected context. Pair with espresso text.",
      "mugshotSage": "Decorative sage and large graphic elements. Do not use with white for small text.",
      "mugshotSageText": "Accessible action fill and green text on cream, foam, and sand.",
      "sandBeige": "Quiet panels, secondary surfaces, and grouped controls.",
      "mugshotLine": "Quiet separators. Insufficient by itself to identify an essential input boundary.",
      "mugshotMatcha": "Supporting drink-context accent, not a replacement primary green.",
      "mugshotLatte": "Supporting warm accent for drink context.",
      "darkRoast": "Deep brown supporting ink.",
      "mapPinHigh": "High-rating map meaning. Always accompany with a number or label.",
      "mapPinMiddle": "Middle-rating map meaning. Always accompany with a number or label.",
      "mapPinLow": "Low-rating map meaning. Always accompany with a number or label.",
      "sageGray": "Legacy alias of mugshotMint; do not create a separate color."
    },
    "typography": {
      "native_display": ".system(size: size, weight: .regular, design: .serif), tracking -0.2 pt",
      "native_body": "System sans; semantic text styles where implemented. Respect Dynamic Type.",
      "web_display": "ui-serif, Georgia, 'Times New Roman', serif",
      "web_body": "-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif",
      "web_tracking": "-0.2px",
      "font_files": "No font binaries are bundled with the native app. No external fonts are part of this kit.",
      "portability": "System faces vary by platform. Georgia and Times are fallbacks, not an assertion of exact SF Serif parity. PDF reference exports use built-in Times and Helvetica.",
      "native_roles": [
        {
          "role": "Brand name",
          "size": 42,
          "weight": 400,
          "source": "authentication",
          "evidence": ".mugshotDisplay(size: 42)"
        },
        {
          "role": "Welcome heading",
          "size": 40,
          "weight": 400,
          "source": "onboarding",
          "evidence": ".mugshotDisplay(size: 40)"
        },
        {
          "role": "Screen heading",
          "size": 30,
          "weight": 400,
          "source": "system",
          "evidence": ".mugshotDisplay(size: 30)"
        },
        {
          "role": "Body / controls",
          "size": 16,
          "weight": 500,
          "source": "authentication",
          "evidence": ".system(size: 16, weight: .medium)"
        }
      ],
      "web_roles": [
        {
          "role": "Hero",
          "value": "clamp(2.5rem, 5.5vw, 5rem)",
          "purpose": "One main marketing statement; regular serif."
        },
        {
          "role": "Section",
          "value": "clamp(2rem, 3vw, 3rem)",
          "purpose": "Serif section headings with natural wrapping."
        },
        {
          "role": "Body",
          "value": "1rem / 1.6",
          "purpose": "System sans, 60-70 characters per line."
        },
        {
          "role": "Label",
          "value": "0.875rem / 1.4",
          "purpose": "System sans; clear sentence case."
        }
      ]
    },
    "logo": {
      "asset": "app-icon",
      "wordmark": "Mugshot",
      "wordmark_rule": "Use live text in the native regular serif role. There is no separately approved vector wordmark in the app.",
      "clear_space": "Web application rule: leave at least one quarter of the displayed icon width around an icon/name lockup; retain all padding inside the source PNG.",
      "minimum": "Web application rule: use the full icon at least 48 CSS px wide; use a text-only name if the embedded mug loses clarity.",
      "lockup_gap": "Web application rule: use the app's 12 px spacing step between the displayed icon and name.",
      "backgrounds": "Prefer cream or white. The original icon includes its own white canvas; do not fake transparency on dark backgrounds.",
      "prohibited": [
        "Redrawing or tracing the mark",
        "Recoloring the icon",
        "Mirroring or stretching",
        "Removing its source padding",
        "Inventing inverse or monochrome variants",
        "Adding a new badge or tagline inside the mark"
      ],
      "gap": "No approved standalone vector logo, inverse logo, monochrome master, CMYK master, or favicon-size redraw exists in the audited app. Keep these as explicit gaps rather than inventing replacements."
    },
    "character": {
      "master": "mugsy-wishlist",
      "rules": [
        "White ceramic, permanent glasses, compact limbs, and the approved silhouette remain unchanged.",
        "Do not mirror, stretch, recolor, crop the handle, or draw new anatomy.",
        "The canonical normalized model keeps the handle on Mugsy's right; preserve the orientation of every source PNG exactly as supplied.",
        "Props remain context layers. The bookmark held in MugsyNoWishlist is a prop.",
        "The code-native model supports positive, context-aware product scenes. Legacy raster poses remain identity references and must not become guilt-based promotional messages.",
        "Use the builder pose only for coming-soon or maintenance contexts.",
        "Keep artwork's own colors separate from the UI palette. Character mint is not the UI mint token.",
        "The existing code-native vector PDF is review-only, not a production replacement for the PNG masters."
      ],
      "motion": "Quiet at rest, responsive to interaction, briefly expressive on completion. No ambient mascot loop in marketing. Honor reduced motion with a still pose.",
      "production_detail": "docs/MUGSY_DESIGN_SYSTEM.md"
    },
    "imagery": {
      "rules": [
        "Use the app-bundled drink imagery and onboarding artwork supplied in the asset manifest.",
        "Show drink texture, natural light, and the surrounding moment. Keep warm, believable color.",
        "Place headlines on a solid cream panel whenever image contrast would be uncertain.",
        "Preserve the drink's focal point when cropping photography. Never distort or crop original character masters.",
        "Keep baked-in onboarding labels intact when showing the complete artwork. It is a reference image, not an editable app screen.",
        "Use bundled reference artwork as illustration, never as proof of a current live account or exact build UI.",
        "Show no personal journal entries, private notes, real user accounts, or live service data in marketing templates.",
        "An app-bundled resource is source provenance; it is not independent verification of third-party licensing or a new redistribution license."
      ]
    },
    "voice": {
      "profile": "Warm, concrete, observant, and unhurried. Short serif-worthy headlines; plain explanatory body copy; verbs that describe what happens next.",
      "perspective": "Speak to the person as you. Use we only for a real Mugshot action or responsibility. Mugsy is a named companion, not the narrator of every sentence.",
      "rhythm": "Favor short statements and natural fragments in headlines. Follow with one useful sentence. Keep UI labels literal.",
      "capitalization": "Mugshot, Mugsy, Map, Feed, Saved, Journal, Friends, Favorites, Want to Try, Lists. Sentence case in new copy; preserve the sourced Capture Every Sip headline.",
      "spelling": "Always cafe and cafes, using ASCII e.",
      "avoid": [
        "Hype or status competition",
        "Expert-only coffee language",
        "Guilt, streak pressure, or forced social sharing",
        "Invented user counts, rankings, reviews, awards, availability, or pricing",
        "Promises that every sip is automatically public",
        "Claims that all app content is private regardless of selected audience"
      ],
      "tones": [
        {
          "context": "Invitation",
          "rule": "Warm and specific. Lead with the memory and let the person choose."
        },
        {
          "context": "Instruction",
          "rule": "Literal action, useful object, clear outcome."
        },
        {
          "context": "Success",
          "rule": "Calm acknowledgement. Celebrate the completed action, not a promised future save."
        },
        {
          "context": "Error",
          "rule": "Say what is known, what remains safe, and the next available action. Use no blame."
        },
        {
          "context": "Privacy",
          "rule": "Use exact audience semantics. Separate private notes from a post's chosen audience."
        }
      ],
      "privacy": "Private means owner-only. Friends means confirmed mutual friends. Everyone means public. Private notes stay private. Describe the selected audience rather than promising blanket privacy."
    },
    "copy": [
      {
        "id": "hero",
        "role": "Primary brand headline",
        "text": "Capture Every Sip",
        "source": "onboarding"
      },
      {
        "id": "intro",
        "role": "Short introduction",
        "text": "The drink. The place. The little moment around it. Mugshot helps you remember it all.",
        "source": "onboarding"
      },
      {
        "id": "range",
        "role": "Drink range",
        "text": "Coffee, matcha, tea, and everything between. Mugsy keeps the little moments that would otherwise disappear.",
        "source": "onboarding"
      },
      {
        "id": "map",
        "role": "Map headline",
        "text": "Watch your world take shape.",
        "source": "onboarding"
      },
      {
        "id": "saved",
        "role": "Saved headline",
        "text": "Never forget the cafe you meant to try.",
        "source": "onboarding"
      },
      {
        "id": "saved-body",
        "role": "Saved explanation",
        "text": "Favorites, Want to Try, and Lists keep the next plan one tap away.",
        "source": "onboarding"
      },
      {
        "id": "journal",
        "role": "Journal headline",
        "text": "A memory, not just a rating.",
        "source": "onboarding"
      },
      {
        "id": "journal-body",
        "role": "Journal explanation",
        "text": "Keep the photo, the feeling, the recipe, and the details you would otherwise forget.",
        "source": "onboarding"
      },
      {
        "id": "friends",
        "role": "Friends headline",
        "text": "Your people. Your pace. Your privacy.",
        "source": "onboarding"
      },
      {
        "id": "privacy",
        "role": "Private notes",
        "text": "Private notes stay private. Choose who can see each post you share.",
        "source": "onboarding"
      },
      {
        "id": "score",
        "role": "Tasting principle",
        "text": "Your reaction is the score",
        "source": "onboarding"
      },
      {
        "id": "signup",
        "role": "Account invitation",
        "text": "Start your sip journal.",
        "source": "authentication"
      }
    ],
    "applications": [
      {
        "name": "Website reference",
        "path": "templates/landing.html",
        "format": "Responsive HTML",
        "purpose": "Cream-led landing page with source imagery, serif hierarchy, and sage actions."
      },
      {
        "name": "Square social",
        "path": "templates/social-square.html",
        "format": "1080 x 1080 composition",
        "purpose": "Photo and journal headline; editable HTML with print styling."
      },
      {
        "name": "Portrait social",
        "path": "templates/social-portrait.html",
        "format": "1080 x 1350 composition",
        "purpose": "Drink photo, Capture Every Sip, and a quiet brand signature."
      },
      {
        "name": "Email reference",
        "path": "templates/email.html",
        "format": "Responsive table HTML",
        "purpose": "Original app icon, cream surface, source copy, and an explicit CTA integration slot."
      }
    ],
    "governance": {
      "owner": "Mugshot product owner",
      "change_rule": "Any identity change updates this kit, its source mapping, the changelog, and affected consumers in the same reviewed change. Do not create a competing palette or voice guide in a downstream repository.",
      "versioning": "Patch: clarification or export repair. Minor: compatible addition. Major: changed identity, semantics, or a breaking token contract.",
      "acceptance": [
        "Only app-source assets and copy",
        "Exact source hashes",
        "Accessible text pairs",
        "Responsive and keyboard review",
        "No fabricated product or release claims",
        "Marketing reference checked against the kit",
        "Documentation and repository checks"
      ],
      "consumer_rule": "Pin the kit version and source commit. Import tokens.css; use the manifest assets and copy library. Record adoption before claiming the marketing site conforms.",
      "drift_command": "python3 scripts/brand-kit.py --check",
      "build_command": "python3 scripts/brand-kit.py --build"
    }
  },
  "tokens": {
    "format": "mugshot-brand-tokens/v1",
    "version": "1.0.0",
    "color": {
      "mugshotMint": "#A8CDB8",
      "mugshotSage": "#6E8F7C",
      "mugshotSageText": "#4D6F5D",
      "mugshotMatcha": "#8FAF6A",
      "mugshotLatte": "#DCC8A6",
      "mapPinHigh": "#4F8A68",
      "mapPinMiddle": "#D4AD55",
      "mapPinLow": "#C26355",
      "creamWhite": "#FAF6F0",
      "foamWhite": "#FFFFFF",
      "espressoBrown": "#1F1712",
      "roastBrown": "#5B4636",
      "darkRoast": "#2B1F17",
      "sandBeige": "#EEE6D8",
      "mugshotLine": "#E3DED4",
      "sageGray": "#A8CDB8"
    },
    "semantic": {
      "canvas": "#FAF6F0",
      "surface": "#FFFFFF",
      "surfaceQuiet": "#EEE6D8",
      "text": "#1F1712",
      "textSecondary": "#5B4636",
      "action": "#4D6F5D",
      "actionText": "#FFFFFF",
      "accent": "#A8CDB8",
      "accentText": "#1F1712",
      "border": "#E3DED4",
      "focus": "#4D6F5D"
    },
    "semanticSources": {
      "canvas": "creamWhite",
      "surface": "foamWhite",
      "surfaceQuiet": "sandBeige",
      "text": "espressoBrown",
      "textSecondary": "roastBrown",
      "action": "mugshotSageText",
      "actionText": "foamWhite",
      "accent": "mugshotMint",
      "accentText": "espressoBrown",
      "border": "mugshotLine",
      "focus": "mugshotSageText"
    },
    "characterColor": {
      "ink": "#0C0C0C",
      "ceramicBase": "#F3F3F3",
      "ceramicHighlight": "#F7F7F7",
      "ceramicShadow": "#D7D6D6",
      "blush": "#E8B8B0",
      "mintAccent": "#B8E0C0"
    },
    "space": {
      "xxs": 4,
      "xs": 8,
      "sm": 12,
      "md": 16,
      "lg": 20,
      "xl": 24,
      "xxl": 32
    },
    "radius": {
      "small": 8,
      "control": 12,
      "card": 16,
      "heroCard": 20,
      "sheet": 24,
      "pill": 999
    },
    "shadow": {
      "cardShadow": {
        "opacity": 0.08,
        "blur": 12,
        "x": 0,
        "y": 4
      },
      "subtleShadow": {
        "opacity": 0.06,
        "blur": 2,
        "x": 0,
        "y": 1
      },
      "overlayShadow": {
        "opacity": 0.12,
        "blur": 30,
        "x": 0,
        "y": 12
      }
    },
    "motionMs": {
      "fast": 150,
      "base": 200,
      "slow": 250
    },
    "pressScale": 0.98,
    "font": {
      "display": "ui-serif, Georgia, 'Times New Roman', serif",
      "body": "-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif"
    },
    "notes": "Colors, spacing, radii, shadows and base motion from native sources. Font fallbacks, responsive type, visible field outline and 44 px web targets are documented web translations."
  },
  "assets": [
    {
      "id": "app-icon",
      "path": "assets/mugshot-app-icon.png",
      "source": "testMugshot/Assets.xcassets/AppIcon.appiconset/mugshot-app-icon.png",
      "sha256": "829d7ebd40fd515d2b5f7753753f489f40c4e97eb7a5c1416718bca3e4e428b0",
      "bytes": 1029601,
      "width": 1024,
      "height": 1024,
      "kind": "identity",
      "use": "Original app icon; retain the complete white canvas and source padding.",
      "transformation": "none; byte-for-byte source copy"
    },
    {
      "id": "mugsy-wishlist",
      "path": "assets/mugsy-wishlist.png",
      "source": "testMugshot/Assets.xcassets/MugsyNoWishlist.imageset/MugsyNoWishlist.png",
      "sha256": "f7f3cfa7658d51d0aba7e32992832abae436ea3a7a87dc736dc593500edb797f",
      "bytes": 29225,
      "width": 500,
      "height": 500,
      "kind": "character-master",
      "use": "Canonical front-facing identity master; preserve the original pose and orientation.",
      "transformation": "none; byte-for-byte source copy"
    },
    {
      "id": "mugsy-favorites",
      "path": "assets/mugsy-favorites.png",
      "source": "testMugshot/Assets.xcassets/MugsyNoFavorites.imageset/MugsyNoFavorites.png",
      "sha256": "9aee76f034d900fcabe97b3f9f642a173e238caff4e06f4b924cf9610ff0a9ef",
      "bytes": 36244,
      "width": 500,
      "height": 500,
      "kind": "character-reference",
      "use": "Favorite-heart pose; original raster expression reference.",
      "transformation": "none; byte-for-byte source copy"
    },
    {
      "id": "mugsy-cafes",
      "path": "assets/mugsy-cafes.png",
      "source": "testMugshot/Assets.xcassets/MugsyNoCafes.imageset/MugsyNoCafes.png",
      "sha256": "0c47ebb14efe29f085b838aeba4f42c4681a72ba77bc4b9a88511986a1bbd435",
      "bytes": 35268,
      "width": 500,
      "height": 500,
      "kind": "character-reference",
      "use": "Cafe-guide pose; original raster expression reference.",
      "transformation": "none; byte-for-byte source copy"
    },
    {
      "id": "mugsy-friends",
      "path": "assets/mugsy-friends.png",
      "source": "testMugshot/Assets.xcassets/MugsyNoFriends.imageset/MugsyNoFriends.png",
      "sha256": "f3f3ed6c6dff67cbf0568f0b89af6555c622287b6a9825ebd76688b14a9c855c",
      "bytes": 26625,
      "width": 500,
      "height": 500,
      "kind": "character-reference",
      "use": "Friends-phone pose; original raster expression reference.",
      "transformation": "none; byte-for-byte source copy"
    },
    {
      "id": "mugsy-builder",
      "path": "assets/mugsy-builder.png",
      "source": "testMugshot/Assets.xcassets/MugsyComingSoon.imageset/MugsyComingSoon.png",
      "sha256": "856b47e641b8a544bc41fdfe9962b238cfd1ef1c1f2d3efce61fc2c0080e9176",
      "bytes": 39389,
      "width": 437,
      "height": 374,
      "kind": "character-reference",
      "use": "Coming-soon or maintenance only; do not use as a missing-photo state.",
      "transformation": "none; byte-for-byte source copy"
    },
    {
      "id": "orange-hero",
      "path": "assets/orange-hero.png",
      "source": "testMugshot/Assets.xcassets/V3OrangeCreamsicleHeroV2.imageset/v3-orange-creamsicle-hero-v2.png",
      "sha256": "bbf227fc62beaa508cc30102599a7e8839c95ad445323bdb04287c7f429f842a",
      "bytes": 1929095,
      "width": 1566,
      "height": 1005,
      "kind": "photography",
      "use": "App-bundled drink illustration; no live-account or venue claim.",
      "transformation": "none; byte-for-byte source copy"
    },
    {
      "id": "orange-square",
      "path": "assets/orange-square.png",
      "source": "testMugshot/Assets.xcassets/V3OrangeCreamsicleSquare.imageset/v3-orange-creamsicle-square.png",
      "sha256": "c7cf6417b090d49b5526a73ce1d986119c9b59898fe106e584bbfa525c76ef00",
      "bytes": 413660,
      "width": 654,
      "height": 654,
      "kind": "photography",
      "use": "App-bundled square drink illustration.",
      "transformation": "none; byte-for-byte source copy"
    },
    {
      "id": "orange-detail",
      "path": "assets/orange-detail.png",
      "source": "testMugshot/Assets.xcassets/V3OrangeCitrusDetail.imageset/v3-orange-citrus-detail.png",
      "sha256": "39e40cb063ed3e05d41758a50434f315bbaaf8a3848ae438d6314e5dd95de9b6",
      "bytes": 351411,
      "width": 624,
      "height": 624,
      "kind": "photography",
      "use": "App-bundled drink detail illustration.",
      "transformation": "none; byte-for-byte source copy"
    },
    {
      "id": "latte",
      "path": "assets/creamy-latte.png",
      "source": "testMugshot/Assets.xcassets/V3CreamyLatte.imageset/v3-creamy-latte.png",
      "sha256": "0489cde87c12b9430580c37a77520e2a7664776f99f03592ca045baf16a81274",
      "bytes": 337742,
      "width": 570,
      "height": 570,
      "kind": "photography",
      "use": "App-bundled latte illustration.",
      "transformation": "none; byte-for-byte source copy"
    },
    {
      "id": "cafe-corner",
      "path": "assets/cafe-corner.png",
      "source": "testMugshot/Assets.xcassets/V3QuietCafeCorner.imageset/v3-quiet-cafe-corner.png",
      "sha256": "3a3e997926099ce801d79a9bdad1cd6081db86fe479b2d0e4f943a0e37ac9822",
      "bytes": 686838,
      "width": 750,
      "height": 750,
      "kind": "photography",
      "use": "App-bundled cafe atmosphere illustration; no named venue claim.",
      "transformation": "none; byte-for-byte source copy"
    },
    {
      "id": "onboarding-capture",
      "path": "assets/onboarding-capture.png",
      "source": "testMugshot/Assets.xcassets/OnboardingMarketing01Capture.imageset/onboarding-marketing-01-capture.png",
      "sha256": "1a64e81abee7432a66aadfd4c1b590104f21d8314a6fc2f56a243edbfffbcdec",
      "bytes": 1841441,
      "width": 852,
      "height": 1846,
      "kind": "onboarding-reference",
      "use": "Complete baked-in app artwork; retain all labels. Not an editable screen or exact build screenshot.",
      "transformation": "none; byte-for-byte source copy"
    },
    {
      "id": "onboarding-map",
      "path": "assets/onboarding-map.png",
      "source": "testMugshot/Assets.xcassets/OnboardingMarketing02Map.imageset/onboarding-marketing-02-map.png",
      "sha256": "c9dcbb9fc41cdd64050d8e835cf069a75cf7f611721fead402692c094f5575db",
      "bytes": 1693535,
      "width": 853,
      "height": 1844,
      "kind": "onboarding-reference",
      "use": "Complete baked-in Map artwork. Not proof of current navigation, data, or release availability.",
      "transformation": "none; byte-for-byte source copy"
    },
    {
      "id": "onboarding-journal",
      "path": "assets/onboarding-journal.png",
      "source": "testMugshot/Assets.xcassets/OnboardingMarketing06Journal.imageset/onboarding-marketing-06-journal.png",
      "sha256": "b8b13adf99d105eaf8bc26cfaf0ed7e555ffd070dc15c42c35b6c85422aa353c",
      "bytes": 1213109,
      "width": 853,
      "height": 1844,
      "kind": "onboarding-reference",
      "use": "Complete baked-in Journal artwork. Not a current live account.",
      "transformation": "none; byte-for-byte source copy"
    }
  ],
  "contrast": [
    {
      "foreground": "espressoBrown",
      "background": "creamWhite",
      "ratio": 16.3972,
      "normal_text": true,
      "large_text": true,
      "use": "Primary text"
    },
    {
      "foreground": "roastBrown",
      "background": "creamWhite",
      "ratio": 8.2157,
      "normal_text": true,
      "large_text": true,
      "use": "Supporting text"
    },
    {
      "foreground": "espressoBrown",
      "background": "mugshotMint",
      "ratio": 10.1632,
      "normal_text": true,
      "large_text": true,
      "use": "Mint panels"
    },
    {
      "foreground": "foamWhite",
      "background": "mugshotSageText",
      "ratio": 5.6039,
      "normal_text": true,
      "large_text": true,
      "use": "Primary actions"
    },
    {
      "foreground": "mugshotSageText",
      "background": "creamWhite",
      "ratio": 5.205,
      "normal_text": true,
      "large_text": true,
      "use": "Green links"
    },
    {
      "foreground": "mugshotSageText",
      "background": "sandBeige",
      "ratio": 4.522,
      "normal_text": true,
      "large_text": true,
      "use": "Green text on sand"
    },
    {
      "foreground": "foamWhite",
      "background": "mugshotSage",
      "ratio": 3.5696,
      "normal_text": false,
      "large_text": true,
      "use": "Avoid for normal text"
    },
    {
      "foreground": "mugshotMint",
      "background": "creamWhite",
      "ratio": 1.6134,
      "normal_text": false,
      "large_text": false,
      "use": "Avoid as body text"
    }
  ]
};
