/* Generated app-source contract. Works offline without fetch. */
window.MUGSHOT_BRAND = {
  "brand": {
    "name": "Mugshot",
    "version": "1.1.0",
    "last_verified": "2026-11-24",
    "source_revision": "1ffba7b074da7b1230942e394a477dc8a5db2911",
    "authority": "This directory is Mugshot's brand authority. The app's immutable identity and tokens remain fixed; user-authorized OpenAI imagery and controlled poses are versioned here and supplied to the app. Marketing consumes the same kit.",
    "scope": "Brand imagery refresh and native pose catalog, implemented in source. This is not an app distribution, a marketing-site deployment, or evidence of physical-device or TestFlight acceptance.",
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
      "artwork_authority": "docs/MUGSY_ASSET_STATUS.md",
      "character_rig": "testMugshot/Views/Components/MugsyModelView.swift",
      "pose_catalog": "testMugshot/Design/MugsyPoseCatalog.swift",
      "identity_contract": "docs/brand/identity/mugsy-spec.json"
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
      "master": "mugsy-identity-master",
      "rules": [
        "MugsyIdentityMaster freezes the original front-facing Mugsy artwork byte-for-byte. It is the reference for every new pose, not a pose to redraw.",
        "White ceramic, the same asymmetric body, rim, right-side handle, glasses, cheek placement, thin limbs, and compact feet stay fixed.",
        "Seven native identity shapes are locked by SHA-256. The renderer shares them across all 18 configurations.",
        "Only expression, gaze, articulated limbs, liquid, outfits, and named accessories vary. Props never replace anatomy or hide the glasses.",
        "Every generation references the immutable master. Full prompts and generation provenance are saved. No identity is recursively re-created from another generated pose.",
        "Each PNG must have true alpha, complete clear margins, a square canvas, an exact reviewed hash, and a recorded optical identity review.",
        "Alpha-derived display registration makes poses fit consistently without altering or cropping the PNG source.",
        "Generated artwork and code-native renders share semantic pose mappings. They are distinct renderings, not a claim of pixel-identical output.",
        "Use native geometry for dynamic product states and generated PNGs for static illustration. Native core construction stays authoritative.",
        "Use the builder only for coming-soon or maintenance. Keep accessories context-specific and expressions positive.",
        "Artwork colors remain separate from UI tokens. Never recolor the ceramic body.",
        "Original legacy rasters are archived under identity/legacy-originals; outdated baked onboarding panels are excluded from the current kit."
      ],
      "motion": "Quiet at rest, responsive to interaction, briefly expressive on completion. No ambient mascot loop in marketing. Honor reduced motion with a still pose.",
      "production_detail": "docs/MUGSY_DESIGN_SYSTEM.md"
    },
    "imagery": {
      "rules": [
        "Use the five current OpenAI-generated photographic-style brand scenes supplied in assets.json. They replace the old drink, latte, cafe, and orange-peel imagery.",
        "Photographic realism means plausible ice and condensation, fine milk texture, natural light, real material detail, and restrained color. Avoid glossy synthetic rendering and excessive garnish.",
        "These are fictional illustrative brand scenes, not captured customer drinks, named real cafes, testimonials, or release evidence.",
        "Keep source PNGs intact. Responsive display crops may preserve the drink focal point; do not distort images.",
        "Use solid cream behind text when image contrast would be uncertain.",
        "Use current named Mugsy poses with the immutable identity contract; do not generate a new Mugsy identity.",
        "Legacy baked onboarding composites remain historical native resources and are not the current brand imagery or screenshots of a new build.",
        "No personal journal, private note, live account, or production service data enters the imagery."
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
    "version": "1.1.0",
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
      "use": "Unchanged original app icon; retain its full source canvas.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "immutable app identity",
      "native_pose": null
    },
    {
      "id": "mugsy-identity-master",
      "path": "assets/mugsy-identity-master.png",
      "source": "testMugshot/Assets.xcassets/MugsyIdentityMaster.imageset/mugsy-identity-master.png",
      "sha256": "f7f3cfa7658d51d0aba7e32992832abae436ea3a7a87dc736dc593500edb797f",
      "bytes": 29225,
      "width": 500,
      "height": 500,
      "kind": "character-master",
      "use": "Immutable original identity reference; do not replace it with a generated variant.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "immutable app identity",
      "native_pose": null
    },
    {
      "id": "mugsy-wave",
      "path": "assets/mugsy-wave.png",
      "source": "testMugshot/Assets.xcassets/MugsyPoseWave.imageset/MugsyPoseWave.png",
      "sha256": "c3fae797355142ba59885f3dfd1e0673be1f3426a0f3eb5baf17ac7542ef62f5",
      "bytes": 489995,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Welcome wave; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "welcomeWave"
    },
    {
      "id": "mugsy-wishlist",
      "path": "assets/mugsy-wishlist.png",
      "source": "testMugshot/Assets.xcassets/MugsyNoWishlist.imageset/MugsyNoWishlist.png",
      "sha256": "5a44009bc9b5319eff38f0981252ef57cd3d544289a5ffcd34d53bdae4f88d41",
      "bytes": 490884,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Want to Try; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "wishlistKeeper"
    },
    {
      "id": "mugsy-favorites",
      "path": "assets/mugsy-favorites.png",
      "source": "testMugshot/Assets.xcassets/MugsyNoFavorites.imageset/MugsyNoFavorites.png",
      "sha256": "995b0bc92b8d63c6b76ca4c15a162b28cf18d1cea3c8ea6fc2259cbe418c2cc3",
      "bytes": 490666,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Favorites; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "heartKeeper"
    },
    {
      "id": "mugsy-scout",
      "path": "assets/mugsy-scout.png",
      "source": "testMugshot/Assets.xcassets/MugsyNoCafes.imageset/MugsyNoCafes.png",
      "sha256": "23fec32c1700e25dec6cdfb435a04aebd9f5a517ec1fa8d61c8806281fd2bad6",
      "bytes": 552665,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Cafe scout; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "cafeScout"
    },
    {
      "id": "mugsy-friends",
      "path": "assets/mugsy-friends.png",
      "source": "testMugshot/Assets.xcassets/MugsyNoFriends.imageset/MugsyNoFriends.png",
      "sha256": "4d1017627ee4704c53766e3b07fd8c60ecc4e98830611fa1bccfd0ed5316a11a",
      "bytes": 472888,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Friends hello; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "friendsHello"
    },
    {
      "id": "mugsy-builder",
      "path": "assets/mugsy-builder.png",
      "source": "testMugshot/Assets.xcassets/MugsyComingSoon.imageset/MugsyComingSoon.png",
      "sha256": "09b83950765cad22884fcfbf56a37501c23be964445c00b7d462e2b0ad82c4d0",
      "bytes": 560202,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Careful builder; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "carefulBuilder"
    },
    {
      "id": "mugsy-camera",
      "path": "assets/mugsy-camera.png",
      "source": "testMugshot/Assets.xcassets/MugsyPoseCamera.imageset/MugsyPoseCamera.png",
      "sha256": "44105e478ae1c5c913f0e7e3db5656038925dc660ae5450636fca6e6cc677fb2",
      "bytes": 467087,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Camera companion; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "cameraCompanion"
    },
    {
      "id": "mugsy-journal",
      "path": "assets/mugsy-journal.png",
      "source": "testMugshot/Assets.xcassets/MugsyPoseJournal.imageset/MugsyPoseJournal.png",
      "sha256": "5b3bd4e90bb996b7a08a271ff0fecf0fda9629c878a74e5574e132dd0ed60825",
      "bytes": 482492,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Journal keeper; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "journalKeeper"
    },
    {
      "id": "mugsy-cozy",
      "path": "assets/mugsy-cozy.png",
      "source": "testMugshot/Assets.xcassets/MugsyPoseCozy.imageset/MugsyPoseCozy.png",
      "sha256": "92c7b56b76e22dd4c6afe100591f291e224d17a30b3752eca334475148aad074",
      "bytes": 556513,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Cozy ritual; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "cozyRitual"
    },
    {
      "id": "mugsy-celebrate",
      "path": "assets/mugsy-celebrate.png",
      "source": "testMugshot/Assets.xcassets/MugsyPoseCelebrate.imageset/MugsyPoseCelebrate.png",
      "sha256": "4b89f0bd496721c7aca62a3812776009afc2cdf6ba614d7b89f7bda39504abb4",
      "bytes": 510437,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "First-sip celebration; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "firstSipCelebration"
    },
    {
      "id": "mugsy-map",
      "path": "assets/mugsy-map.png",
      "source": "testMugshot/Assets.xcassets/MugsyPoseMap.imageset/MugsyPoseMap.png",
      "sha256": "7bdfac454869a5318f8d886158ea1924b397f66cd5cd83db1d18d998dfb160c0",
      "bytes": 506594,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Map explorer; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "mapExplorer"
    },
    {
      "id": "mugsy-beans",
      "path": "assets/mugsy-beans.png",
      "source": "testMugshot/Assets.xcassets/MugsyPoseBeans.imageset/MugsyPoseBeans.png",
      "sha256": "c8258c7575628807e55cfc32a16b0863875f8bb836a367698d5aee9b6f11bdb6",
      "bytes": 479997,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Bean keeper; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "beanKeeper"
    },
    {
      "id": "mugsy-matcha",
      "path": "assets/mugsy-matcha.png",
      "source": "testMugshot/Assets.xcassets/MugsyPoseMatcha.imageset/MugsyPoseMatcha.png",
      "sha256": "53403ee7190221dba595fef6b3d165e7fc64a3e302ff8cf751f3e795bea95857",
      "bytes": 502234,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Matcha maker; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "matchaMaker"
    },
    {
      "id": "mugsy-pourover",
      "path": "assets/mugsy-pourover.png",
      "source": "testMugshot/Assets.xcassets/MugsyPosePourOver.imageset/MugsyPosePourOver.png",
      "sha256": "efcb2d8dabb05818c1ea70dc8a29baa6ff2a6e25b67ed2e9cd73f4f9013f2d8d",
      "bytes": 513062,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Pour-over barista; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "pourOverBarista"
    },
    {
      "id": "mugsy-takeaway",
      "path": "assets/mugsy-takeaway.png",
      "source": "testMugshot/Assets.xcassets/MugsyPoseTakeaway.imageset/MugsyPoseTakeaway.png",
      "sha256": "48a7286dfc2c13267ce5732c2e99e3a46a79d34de80ab552887ac09bc0a4de5c",
      "bytes": 508278,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Takeaway companion; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "takeawayCompanion"
    },
    {
      "id": "mugsy-tasting",
      "path": "assets/mugsy-tasting.png",
      "source": "testMugshot/Assets.xcassets/MugsyPoseTasting.imageset/MugsyPoseTasting.png",
      "sha256": "a13a8034ed7fb2e7e3029ed765685d4c04b2ed31d424e7bef5b55ff6b6919aca",
      "bytes": 502352,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Taste explorer; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "tasteExplorer"
    },
    {
      "id": "mugsy-guide",
      "path": "assets/mugsy-guide.png",
      "source": "testMugshot/Assets.xcassets/MugsyPoseGuide.imageset/MugsyPoseGuide.png",
      "sha256": "3d8da1baa5db7fc5418a0223bf75bd26e4e3baf133aa8db76320a61ab7594fd2",
      "bytes": 488859,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Helpful guide; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "helpfulGuide"
    },
    {
      "id": "mugsy-pause",
      "path": "assets/mugsy-pause.png",
      "source": "testMugshot/Assets.xcassets/MugsyPosePause.imageset/MugsyPosePause.png",
      "sha256": "77a2cefa4fb03d342d1ac8a48b12c5ed281a41735837a08c956af90c90f2861d",
      "bytes": 439920,
      "width": 1254,
      "height": 1254,
      "kind": "character-pose",
      "use": "Quiet pause; reviewed OpenAI-generated pose, paired with MugsyCatalogPose.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": "quietPause"
    },
    {
      "id": "orange-hero",
      "path": "assets/orange-hero.png",
      "source": "testMugshot/Assets.xcassets/V3OrangeCreamsicleHeroV2.imageset/v3-orange-creamsicle-hero-v2.png",
      "sha256": "0d30cb424a6fa5230fc18a04541cfa871eb6c8c81c6ea5bc2353ca22344d5a08",
      "bytes": 2313483,
      "width": 1536,
      "height": 1024,
      "kind": "photography",
      "use": "OpenAI-generated signature iced coffee and orange-peel scene; not a real venue claim.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": null
    },
    {
      "id": "orange-square",
      "path": "assets/orange-square.png",
      "source": "testMugshot/Assets.xcassets/V3OrangeCreamsicleSquare.imageset/v3-orange-creamsicle-square.png",
      "sha256": "9ecedeaafbeb1945c1c72f60029d2b74b23b48eb59fd0885d2b90304998d7d78",
      "bytes": 2476012,
      "width": 1254,
      "height": 1254,
      "kind": "photography",
      "use": "OpenAI-generated square signature drink scene.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": null
    },
    {
      "id": "orange-detail",
      "path": "assets/orange-detail.png",
      "source": "testMugshot/Assets.xcassets/V3OrangeCitrusDetail.imageset/v3-orange-citrus-detail.png",
      "sha256": "3676b6688245d4f83ee6ee621e02b3e96b84560c22cb41ff52661e7e799eb1fd",
      "bytes": 2297680,
      "width": 1254,
      "height": 1254,
      "kind": "photography",
      "use": "OpenAI-generated close view of ice, milk, glass, and orange peel.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": null
    },
    {
      "id": "latte",
      "path": "assets/creamy-latte.png",
      "source": "testMugshot/Assets.xcassets/V3CreamyLatte.imageset/v3-creamy-latte.png",
      "sha256": "c3b4a322b4a578eea13cc9b42e1f5f50786fc788a29a350cc8b06f47187d7e0d",
      "bytes": 2302613,
      "width": 1254,
      "height": 1254,
      "kind": "photography",
      "use": "OpenAI-generated flat white and ceramic texture scene.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": null
    },
    {
      "id": "cafe-corner",
      "path": "assets/cafe-corner.png",
      "source": "testMugshot/Assets.xcassets/V3QuietCafeCorner.imageset/v3-quiet-cafe-corner.png",
      "sha256": "d7fe5438a4d13c43b5710dd388bc1bb542fa528a10a7a4f0214fb5855c587fcf",
      "bytes": 2158953,
      "width": 1254,
      "height": 1254,
      "kind": "photography",
      "use": "OpenAI-generated fictional neighborhood cafe; no named venue claim.",
      "transformation": "none; byte-for-byte native resource copy",
      "origin": "OpenAI-generated source artwork",
      "native_pose": null
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
  ],
  "mugsy": {
    "schema": "mugshot-mugsy-identity/v1",
    "version": "1.0.0",
    "identity_source_commit": "1ffba7b074da7b1230942e394a477dc8a5db2911",
    "native_master": "MugsyIdentityMaster",
    "reference_path": "testMugshot/Assets.xcassets/MugsyIdentityMaster.imageset/mugsy-identity-master.png",
    "reference_sha256": "f7f3cfa7658d51d0aba7e32992832abae436ea3a7a87dc736dc593500edb797f",
    "canvas": {
      "native_units": [
        500,
        500
      ],
      "raster_rule": "Square RGBA PNG, complete body and accessories, genuine alpha and clear margins; no generated checkerboard."
    },
    "invariants": [
      "Same asymmetrical white ceramic body and elliptical open rim",
      "Same rounded rectangular black glasses, bridge, temple, eye placement and cheek locations",
      "Handle stays on the image right; never mirror",
      "Same thin black arms/legs and compact mitten hands/feet",
      "Locked native palette and core geometry; accessories cannot recolor ceramic or obscure glasses",
      "Only expression, gaze, articulated limbs, liquid and accessories may change",
      "Every generation uses the immutable master; never chain identities from one generated pose to the next",
      "Generated art needs visual identity review; hashes and alpha checks alone cannot prove identity"
    ],
    "core_geometry_sha256": {
      "MugsyBodyShape": "9be142b158acd02da235c76cef759177d62b9c0323d776887bd8a0dde5ac43a4",
      "MugsyRimShape": "444901f48525318db48d0a12c012ece0cfe172bd1d8da3ef763d7244747e9f2e",
      "MugsyRimInteriorShape": "f5adfc7f9f9ceb51b58dbed213237aa8d46b602962644c8e1eb0fa11f97ffe3e",
      "MugsyHandleShape": "c86dfb6fe6d9d0ae36841ac916be72f0ffebe6a9effcfc27dfcc456660c06d29",
      "MugsyGlassesShape": "215424816cf3f8d6e46e33dedd17222fe867c05eae0008b776c10922e7b0758d",
      "MugsyCheeksShape": "40ffcd1a7c50fe99701c815135d83a10fd6db32f186d8e553b158da8e1c8a4b9",
      "MugsyFootShape": "971f325a787801958db72eb3540a30ab689dbcee11b8e4d032d3f2d9b1810854"
    },
    "palette": {
      "ink": "#0C0C0C",
      "ceramic": "#F3F3F3",
      "highlight": "#F7F7F7",
      "shadow": "#D7D6D6",
      "blush": "#E8B8B0",
      "accessoryMint": "#B8E0C0"
    },
    "poses": [
      {
        "id": "wave",
        "native_case": "welcomeWave",
        "asset_name": "MugsyPoseWave",
        "export_name": "mugsy-wave.png",
        "title": "Welcome wave",
        "expression": "delighted",
        "prop": "none",
        "outfit": "none",
        "arm_pose": "wavingLeft",
        "pose": "neutral",
        "brief": "Raise the arm on the image LEFT in a small welcoming wave, other arm relaxed. Gentle happy smile, feet planted.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.212121,
          0.300638,
          0.597289,
          0.535885
        ],
        "artwork_sha256": "c3fae797355142ba59885f3dfd1e0673be1f3426a0f3eb5baf17ac7542ef62f5",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "wishlist",
        "native_case": "wishlistKeeper",
        "asset_name": "MugsyNoWishlist",
        "export_name": "mugsy-wishlist.png",
        "title": "Want to Try",
        "expression": "delighted",
        "prop": "wishlistBadge",
        "outfit": "none",
        "arm_pose": "crossedOverProp",
        "pose": "neutral",
        "brief": "Hold a small white bookmark badge under the same crossed arms as the identity reference, with a calm delighted smile instead of sadness. No letters on the bookmark.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.284689,
          0.300638,
          0.527113,
          0.533493
        ],
        "artwork_sha256": "5a44009bc9b5319eff38f0981252ef57cd3d544289a5ffcd34d53bdae4f88d41",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "favorites",
        "native_case": "heartKeeper",
        "asset_name": "MugsyNoFavorites",
        "export_name": "mugsy-favorites.png",
        "title": "Favorites",
        "expression": "delighted",
        "prop": "favoriteHeart",
        "outfit": "none",
        "arm_pose": "cradling",
        "pose": "neutral",
        "brief": "Cradle a small blush-pink heart at lower belly level with both hands. Warm delighted smile and gently raised brows.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.285486,
          0.302233,
          0.527911,
          0.531898
        ],
        "artwork_sha256": "995b0bc92b8d63c6b76ca4c15a162b28cf18d1cea3c8ea6fc2259cbe418c2cc3",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "scout",
        "native_case": "cafeScout",
        "asset_name": "MugsyNoCafes",
        "export_name": "mugsy-scout.png",
        "title": "Cafe scout",
        "expression": "delighted",
        "prop": "guidebookAndPen",
        "outfit": "cafeScout",
        "arm_pose": "reading",
        "pose": "neutral",
        "brief": "Wear a small muted-mint soft scouting hat above the rim; hold an open plain cream guidebook and a small pen at belly level, looking interested. No desk, background, text, or lettering.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.283094,
          0.176236,
          0.529506,
          0.658692
        ],
        "artwork_sha256": "23fec32c1700e25dec6cdfb435a04aebd9f5a517ec1fa8d61c8806281fd2bad6",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "friends",
        "native_case": "friendsHello",
        "asset_name": "MugsyNoFriends",
        "export_name": "mugsy-friends.png",
        "title": "Friends hello",
        "expression": "delighted",
        "prop": "friendsPhone",
        "outfit": "none",
        "arm_pose": "holdingCenter",
        "pose": "neutral",
        "brief": "Hold a small black phone with a mint screen showing two tiny simple person silhouettes, at lower belly level. Welcoming happy smile. No screen text.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.283094,
          0.301435,
          0.528708,
          0.535088
        ],
        "artwork_sha256": "4d1017627ee4704c53766e3b07fd8c60ecc4e98830611fa1bccfd0ed5316a11a",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "builder",
        "native_case": "carefulBuilder",
        "asset_name": "MugsyComingSoon",
        "export_name": "mugsy-builder.png",
        "title": "Careful builder",
        "expression": "delighted",
        "prop": "builderTools",
        "outfit": "builder",
        "arm_pose": "presenting",
        "pose": "neutral",
        "brief": "Wear a small mint hard hat above the rim and a simple mint apron below the face. Hold a tiny hammer and wrench at belly level. Cheerful, competent, no construction site or extra objects.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.283892,
          0.200159,
          0.527113,
          0.637161
        ],
        "artwork_sha256": "09b83950765cad22884fcfbf56a37501c23be964445c00b7d462e2b0ad82c4d0",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "camera",
        "native_case": "cameraCompanion",
        "asset_name": "MugsyPoseCamera",
        "export_name": "mugsy-camera.png",
        "title": "Camera companion",
        "expression": "delighted",
        "prop": "camera",
        "outfit": "cameraCompanion",
        "arm_pose": "holdingCamera",
        "pose": "neutral",
        "brief": "Hold a small black camera with one round white lens and subtle mint inset, a thin camera strap below the face. Delighted gentle smile, camera at lower belly level without hiding the glasses.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.282297,
          0.299841,
          0.530303,
          0.535088
        ],
        "artwork_sha256": "44105e478ae1c5c913f0e7e3db5656038925dc660ae5450636fca6e6cc677fb2",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "journal",
        "native_case": "journalKeeper",
        "asset_name": "MugsyPoseJournal",
        "export_name": "mugsy-journal.png",
        "title": "Journal keeper",
        "expression": "focused",
        "prop": "journalNotebook",
        "outfit": "none",
        "arm_pose": "writing",
        "pose": "neutral",
        "brief": "Hold a small cream notebook at belly level and write with a small black pen. Calm focused eyes looking slightly down, soft happy closed smile. No desk, no writing or lettering.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.284689,
          0.301435,
          0.527911,
          0.533493
        ],
        "artwork_sha256": "5b3bd4e90bb996b7a08a271ff0fecf0fda9629c878a74e5574e132dd0ed60825",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "cozy",
        "native_case": "cozyRitual",
        "asset_name": "MugsyPoseCozy",
        "export_name": "mugsy-cozy.png",
        "title": "Cozy ritual",
        "expression": "delighted",
        "prop": "journalNotebook",
        "outfit": "cozyRitual",
        "arm_pose": "reading",
        "pose": "neutral",
        "brief": "Wear a small pale-mint knitted wrap around only the lower half of the mug body, keeping face and handle completely exposed. Hold a small cream notebook at belly level. Quiet contented smile, a little coffee visible inside the open rim, two fine restrained steam curls.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.278309,
          0.169059,
          0.53429,
          0.665869
        ],
        "artwork_sha256": "92c7b56b76e22dd4c6afe100591f291e224d17a30b3752eca334475148aad074",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "celebrate",
        "native_case": "firstSipCelebration",
        "asset_name": "MugsyPoseCelebrate",
        "export_name": "mugsy-celebrate.png",
        "title": "First-sip celebration",
        "expression": "delighted",
        "prop": "none",
        "outfit": "none",
        "arm_pose": "handsRaised",
        "pose": "neutral",
        "brief": "Lift BOTH small mitten hands in a happy celebratory pose. Knees slightly bent with feet planted, tiny body lowering but no stretching or change of body proportions. Delighted smile. No confetti, ribbons, stars, background or extra objects.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.246411,
          0.302233,
          0.566188,
          0.524721
        ],
        "artwork_sha256": "4b89f0bd496721c7aca62a3812776009afc2cdf6ba614d7b89f7bda39504abb4",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "map",
        "native_case": "mapExplorer",
        "asset_name": "MugsyPoseMap",
        "export_name": "mugsy-map.png",
        "title": "Map explorer",
        "expression": "curious",
        "prop": "mapAndCompass",
        "outfit": "none",
        "arm_pose": "presenting",
        "pose": "neutral",
        "brief": "Hold a small folded muted-mint paper map at belly level and a tiny simple round compass. Curious, inviting eyes, soft smile. Use simple abstract map lines, no text, no location labels, no hat.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.283892,
          0.300638,
          0.529506,
          0.535088
        ],
        "artwork_sha256": "7bdfac454869a5318f8d886158ea1924b397f66cd5cd83db1d18d998dfb160c0",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "beans",
        "native_case": "beanKeeper",
        "asset_name": "MugsyPoseBeans",
        "export_name": "mugsy-beans.png",
        "title": "Bean keeper",
        "expression": "delighted",
        "prop": "coffeeBeans",
        "outfit": "none",
        "arm_pose": "holdingCenter",
        "pose": "neutral",
        "brief": "Hold a small cream paper coffee-bean bag at belly level, a muted-mint band and a single black coffee-bean outline as the only label. Happy attentive smile. No lettering, loose beans or background.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.283094,
          0.300638,
          0.522329,
          0.535885
        ],
        "artwork_sha256": "c8258c7575628807e55cfc32a16b0863875f8bb836a367698d5aee9b6f11bdb6",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "matcha",
        "native_case": "matchaMaker",
        "asset_name": "MugsyPoseMatcha",
        "export_name": "mugsy-matcha.png",
        "title": "Matcha maker",
        "expression": "focused",
        "prop": "matchaKit",
        "outfit": "none",
        "arm_pose": "presenting",
        "pose": "neutral",
        "brief": "Hold a small white matcha bowl with a muted-mint green drink and a simple bamboo whisk at lower belly level. Focused cheerful face. Whisk and bowl must be small accessories, not additional characters. No table, no background.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.284689,
          0.301435,
          0.527911,
          0.533493
        ],
        "artwork_sha256": "53403ee7190221dba595fef6b3d165e7fc64a3e302ff8cf751f3e795bea95857",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "pourover",
        "native_case": "pourOverBarista",
        "asset_name": "MugsyPosePourOver",
        "export_name": "mugsy-pourover.png",
        "title": "Pour-over barista",
        "expression": "focused",
        "prop": "pourOverKit",
        "outfit": "baristaApron",
        "arm_pose": "presenting",
        "pose": "neutral",
        "brief": "Wear a small muted-mint apron BELOW the glasses. Hold a small white conical pour-over dripper on a little glass server and a miniature simple gooseneck kettle at lower belly level. Focused soft smile, no table or scene. Keep all accessories separated from his ceramic anatomy.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.271132,
          0.300638,
          0.541467,
          0.535088
        ],
        "artwork_sha256": "efcb2d8dabb05818c1ea70dc8a29baa6ff2a6e25b67ed2e9cd73f4f9013f2d8d",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "takeaway",
        "native_case": "takeawayCompanion",
        "asset_name": "MugsyPoseTakeaway",
        "export_name": "mugsy-takeaway.png",
        "title": "Takeaway companion",
        "expression": "delighted",
        "prop": "takeawayCup",
        "outfit": "none",
        "arm_pose": "holdingCenter",
        "pose": "neutral",
        "brief": "Hold a small unbranded white takeaway cup with a black lid and mint sleeve at belly level. The little takeaway cup has no face or limbs. Friendly soft smile. No logos or lettering.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.284689,
          0.302233,
          0.527113,
          0.532695
        ],
        "artwork_sha256": "48a7286dfc2c13267ce5732c2e99e3a46a79d34de80ab552887ac09bc0a4de5c",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "tasting",
        "native_case": "tasteExplorer",
        "asset_name": "MugsyPoseTasting",
        "export_name": "mugsy-tasting.png",
        "title": "Taste explorer",
        "expression": "curious",
        "prop": "tastingSpoon",
        "outfit": "none",
        "arm_pose": "presenting",
        "pose": "neutral",
        "brief": "Hold a small simple tasting spoon, raised only to lower-belly height and clearly below the mouth. Curious engaged gaze and a warm closed smile. Keep the same glasses, handle and mug silhouette. No other objects.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.283892,
          0.301435,
          0.528708,
          0.53429
        ],
        "artwork_sha256": "a13a8034ed7fb2e7e3029ed765685d4c04b2ed31d424e7bef5b55ff6b6919aca",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "guide",
        "native_case": "helpfulGuide",
        "asset_name": "MugsyPoseGuide",
        "export_name": "mugsy-guide.png",
        "title": "Helpful guide",
        "expression": "curious",
        "prop": "none",
        "outfit": "none",
        "arm_pose": "presenting",
        "pose": "neutral",
        "brief": "Present both empty palms outward gently at belly level as if offering helpful guidance. Curious eyes and a calm little smile. No sign, book, accessories, clothing or text.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.282297,
          0.299841,
          0.527911,
          0.535088
        ],
        "artwork_sha256": "3d8da1baa5db7fc5418a0223bf75bd26e4e3baf133aa8db76320a61ab7594fd2",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      },
      {
        "id": "pause",
        "native_case": "quietPause",
        "asset_name": "MugsyPosePause",
        "export_name": "mugsy-pause.png",
        "title": "Quiet pause",
        "expression": "neutral",
        "prop": "none",
        "outfit": "none",
        "arm_pose": "relaxed",
        "pose": "neutral",
        "brief": "Both arms rest naturally at his sides, feet planted, calm bright eyes and a small relaxed closed smile. A small amount of coffee visible ONLY inside his open rim, no steam, no clothing or extra objects.",
        "generation_status": "identity-reviewed",
        "artwork_bounds": [
          0.282297,
          0.301435,
          0.530303,
          0.531898
        ],
        "artwork_sha256": "77a2cefa4fb03d342d1ac8a48b12c5ed281a41735837a08c956af90c90f2861d",
        "optical_review": "Codex visual review: same ceramic silhouette family, glasses, right-side handle and palette; complete pose and correct accessory. Native rig stays geometrically exact; generated artwork is not asserted pixel-identical."
      }
    ]
  }
};
