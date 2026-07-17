# Mugshot Tasting Lens 2.0 — Phase 1 Research and Product Direction

Date: 2026-07-16

Status: Research complete; visual selection required before state-sheet design or production implementation

Repository checkpoint: fd73821 on codex/ui-ux-polish-testing-pass

## Executive recommendation

Tasting Lens should become a guided personal-observation system, not a simplified professional cupping form.

The core model should preserve five separate kinds of information:

1. **Observation:** what the user notices.
2. **Intensity:** how strongly it is present.
3. **Personal preference:** how much the user enjoys it.
4. **Quality impression:** an optional, explicitly subjective judgment used only when it helps.
5. **Confidence:** whether the user is sure, tentative, or still learning.

Mugshot should never combine these into a hidden weighted score. The existing 1–5 overall score should remain an independent personal rating with plain-language half-step anchors. The Taste Snapshot should summarize the sensory record without producing a second authoritative score.

The professional precedent is the Specialty Coffee Association's current Coffee Value Assessment: descriptive, affective, physical, and extrinsic information are complementary rather than collapsed into one number. Mugshot should adopt that separation principle while creating an original, smaller, consumer-friendly system. It should not reproduce the CVA forms, the World Coffee Research lexicon, or a proprietary flavor wheel.

Mugshot's safe product claim is:

> A guided personal tasting journal informed by sensory science and professional beverage evaluation.

Mugshot must not claim to Q grade a drink, certify or calibrate a palate, diagnose extraction, determine objective quality, or make different users' scores professionally comparable.

## Evidence labels

- **Established science:** supported by sensory-science research or repeatable empirical findings.
- **Professional convention:** a standard or trained-professional practice; useful context but not automatically appropriate for consumers.
- **Product interpretation:** a Mugshot design choice derived from the evidence and current product constraints.
- **Open question:** a claim or design decision that needs validation and should not be presented as settled fact.

## 1. Cited sensory-expertise brief

### 1.1 Flavor is a sequence of different sensory channels

**Established science.** Flavor combines taste, orthonasal aroma before a sip, retronasal aroma during and after a sip, tactile sensations, temperature, and trigeminal sensations. Aroma words such as floral, peach, cocoa, or toast are not basic tastes. Astringency is a tactile drying or gripping sensation and must not be merged with bitterness. Sources: [NIDCD taste and smell overview](https://www.nidcd.nih.gov/health/statistics/what-numbers-mean-epidemiological-perspective-taste-smell), [systematic review of retronasal methods](https://pmc.ncbi.nlm.nih.gov/articles/PMC6335936/), and [astringency review](https://pubmed.ncbi.nlm.nih.gov/38591722/).

**Product interpretation.** The universal novice sequence should be:

1. Before sipping: what reaches the nose?
2. First sip: which taste or sensation leads?
3. In the mouth: what is the weight, flow, texture, coating, or dryness?
4. As it changes temperature: what becomes clearer, softer, stronger, or simply different?
5. After swallowing: what aroma, taste, and physical feeling remain?

The three parts of the finish should be stored independently: residual aroma, residual taste, and residual mouthfeel.

### 1.2 Description, intensity, liking, and quality are not synonyms

**Established science and professional convention.** ISO sensory guidance distinguishes objective sensory analysis from consumer hedonic preference, and the SCA CVA separates descriptive assessment from affective impression. The current CVA descriptive form records attributes and intensity, while the affective form separately records impression of quality. Sources: [ISO 6658:2017](https://www.iso.org/standard/65519.html), [ISO 4121:2003](https://www.iso.org/standard/33817.html), [SCA Coffee Value Assessment](https://sca.coffee/value-assessment), and [current CVA forms](https://sca.coffee/s/CVA-Cupping-Forms-EN.pdf).

**Product interpretation.** A high bitterness, acidity, roast, umami, body, or astringency rating is not automatically good or bad. Mugshot should first ask how strong a sensation is, then separately ask whether the user enjoyed how it worked in the drink.

### 1.3 Sensory vocabulary needs definitions, examples, and humility

**Professional convention.** The World Coffee Research Sensory Lexicon defines 110 coffee attributes with physical references and trained-panel intensity values. It is a measurement resource, not a quality score, and its use assumes substantially more training and control than a consumer journal. Source: [WCR Sensory Lexicon overview](https://worldcoffeeresearch.org/resources/sensory-lexicon).

**Established science.** Consumer checklists can create primacy and order bias: terms near the top or made more salient may be selected more often. Source: [Ares and Jaeger on CATA attribute-order bias](https://www.sciencedirect.com/science/article/pii/S0950329312001838).

**Product interpretation.** Mugshot should invite one neutral, free observation before showing descriptor suggestions. Suggestions should be broad, balanced, and ordered by the sensory sequence rather than by supposed desirability. The user can always answer “not sure yet.”

### 1.4 Temperature matters, but there is no universal direction

**Established science.** Coffee and tea perception can change with serving temperature, but the direction and size of change depend on the beverage, attribute, preparation, and person. Brewing-water temperature is also not equivalent to consumption temperature. Sources: [coffee serving-temperature study](https://www.sciencedirect.com/science/article/pii/S0963996918309761), [controlled drip-brew temperature study](https://pmc.ncbi.nlm.nih.gov/articles/PMC7536440/), [green-tea serving-temperature study](https://pmc.ncbi.nlm.nih.gov/articles/PMC5769193/), [human sweet-temperature study](https://pmc.ncbi.nlm.nih.gov/articles/PMC4542652/), and [human bitter-temperature study](https://pmc.ncbi.nlm.nih.gov/articles/PMC5390503/).

**Product interpretation.** Prompt “What changed?” rather than “Did it get sweeter?” A valid answer is “nothing I could name.”

### 1.5 Repeated sipping changes the experience

**Established science.** Continuous stimulation can produce taste adaptation, ordinary sipping can interrupt that adaptation, and astringency may accumulate across sips. Sources: [taste-adaptation experiment](https://pubmed.ncbi.nlm.nih.gov/10909251/) and [serial green-tea phenolic exposure](https://pubmed.ncbi.nlm.nih.gov/36652684/).

**Product interpretation.** Guided mode needs only one later-sip check. Deep mode may compare first sip, later sip, and finish. The app should never imply that either the first or last impression is more correct.

### 1.6 Professional calibration is not consumer reflection

**Professional convention.** The current SCA Q Grader program is a professional credential for experienced cuppers, with intensive training, formal assessments, and continuing requirements. It is not something an untrained user approximates by completing an app flow. Source: [SCA Q Grader program](https://sca.coffee/education/q-grader).

Tea has the same boundary. ISO 3103 defines a repeatable preparation method for comparative tea sensory work, not the best home-drinking recipe. Professional matcha evaluation may examine color, particle size, foaming, foam color, texture, and harmony. Sources: [ISO 3103:2019](https://www.iso.org/standard/73224.html), [ISO/TR 21380:2022 matcha](https://www.iso.org/standard/80777.html), and [Japanese matcha sensory evaluation](https://doi.org/10.5979/cha.2022.134_31).

**Product interpretation.** Product copy should say “guided observation,” “personal tasting note,” and “sensory-science-informed.” It should never say “official assessment,” “Q score,” “certified,” “calibrated palate,” or “objective quality.”

## 2. Source-quality and confidence table

| Source | Type and quality | Best-supported use | Important limitation | Confidence |
| --- | --- | --- | --- | --- |
| [SCA Coffee Value Assessment](https://sca.coffee/value-assessment) and [forms](https://sca.coffee/s/CVA-Cupping-Forms-EN.pdf) | Current primary professional standard | Separate descriptive, affective, physical, and extrinsic information; staged sensory dimensions | Professional coffee assessment, not a consumer UI or universal personal score | Very high within professional scope |
| [WCR Sensory Lexicon](https://worldcoffeeresearch.org/resources/sensory-lexicon) | Primary research resource developed for trained sensory work | Value-neutral coffee vocabulary, definitions, references, and intensity calibration | Copyright/licensing; 110 terms and reference recipes should not be copied wholesale; references can be culture-specific | Very high for trained coffee description |
| [SCA Q Grader](https://sca.coffee/education/q-grader) | Current certification authority | Establishes the professional-certification boundary | Does not validate a consumer tasting journey | Very high |
| [ISO 6658](https://www.iso.org/standard/65519.html), [ISO 4121](https://www.iso.org/standard/33817.html), and [ISO 11136](https://www.iso.org/standard/50125.html) | International sensory standards | Separate analytical and hedonic work; use anchored response scales | Full standards are licensed; not beverage-specific UX guidance | Very high for method principles |
| [SCA/WCC 2026 rules](https://wcc.coffee/rules-regulations) | Current professional competition convention | Vocabulary for flavor, finish, tactile structure, milk integration, and evaluation order | Competition judging is not general science or everyday drinking | High within competition scope |
| [UC Davis coffee research](https://coffeecenter.ucdavis.edu/faculty-research/publications) | Peer-reviewed controlled coffee studies | Effects of extraction, strength, roast, brew and serving temperature, and cold extraction | Findings are conditional on samples, recipes, and controls | High within tested conditions |
| [Cold-brew sensory study](https://www.mdpi.com/2304-8158/11/16/2440) | Peer-reviewed primary study | Cold- versus hot-extracted full-immersion profiles at controlled strength and serving temperature | Does not cover every concentrate, chilled hot brew, ice level, or recipe | High within tested conditions |
| [Milk and coffee study](https://pmc.ncbi.nlm.nih.gov/articles/PMC12147775/) | Recent peer-reviewed primary study | Milk can change bitterness dominance, coffee expression, aroma, and integration | Not a complete steamed-cafe-drink or foam study | Medium-high |
| [Retronasal review](https://pmc.ncbi.nlm.nih.gov/articles/PMC6335936/) and [astringency review](https://pmc.ncbi.nlm.nih.gov/articles/PMC7465539/) | Peer-reviewed reviews | Distinguish aroma routes, taste, and tactile dryness | General sensory science rather than beverage-specific prompts | High |
| [Green-tea lexicon](https://doi.org/10.1111/j.1745-459X.2007.00105) | Peer-reviewed trained-panel study across 138 samples | Broad green-tea vocabulary and reference methodology | Older and culturally bounded references need localization | High for studied samples |
| [Blended-tea lexicon](https://pmc.ncbi.nlm.nih.gov/articles/PMC6342540/) | Peer-reviewed trained-panel study | Ingredient-specific herbal and blended-tea vocabulary | Limited products and ingredients | Medium-high |
| [White-tea odorant study](https://pmc.ncbi.nlm.nih.gov/articles/PMC7767441/) and [oolong process study](https://pmc.ncbi.nlm.nih.gov/articles/PMC10314214/) | Peer-reviewed primary studies | Broad floral, fruit, fresh, sweet, roast, and process-driven differences | Specific cultivars, regions, and preparations | Medium-high |
| [Japanese matcha evaluation](https://doi.org/10.5979/cha.2022.134_31) | Japanese professional technical publication | Color, particle size, foam, smoothness, and harmony | Professional convention rather than consumer preference | High |
| [NARO hojicha odorants](https://doi.org/10.5979/cha.2012.114_65) and [roasted-stem study](https://doi.org/10.3136/fstr.26.643) | Japanese primary research | Sweet, roast, and green aroma contributions; roasting effects | Aroma chemistry is not a complete consumer profile | High for tested materials |
| Current repository models and screenshots | Primary product evidence at fd73821 | Current interaction, scoring, persistence, versioning, and brand behavior | Existing checkpoint screenshots are design grounding, not a new accessibility certification | High |

### Confidence policy for knowledge content

Every knowledge item should carry:

- source ID and link;
- evidence class;
- confidence: high, medium, or exploratory;
- beverage and preparation applicability;
- locale and reference-culture metadata;
- content version and review date;
- license or reuse note;
- an explicit “do not infer” rule where users could mistake association for diagnosis.

## 3. Beverage-family sensory matrix

The descriptors below are possibility menus, not notes a user is expected to find. “Unexpected” prompts are neutral invitations, not declarations that a drink is defective.

| Beverage family | What a novice should notice | Accessible vocabulary | Structure, texture, finish, and temperature | Beverage-specific criteria and gentle unexpected-note prompts |
| --- | --- | --- | --- | --- |
| Espresso and straight coffee | Aroma before and during the sip; sweet impression, sourness, bitterness; one broad aromatic family; thickness, texture, dryness; finish; change across the short cup | fruit, floral, cocoa, nut, caramel, spice, roast, cereal, green/herbal, earthy/woody, fermented | Separate thickness from smooth/rough texture and drying. Compare first comfortable sip with a later sip. Crema may change visual expectation and aroma release but is not a quality proxy. | Optional crema observation; intensity and integration. Ask whether anything feels sharper, harsher, more burnt, more metallic, rougher, thinner, or more hollow than expected without diagnosing the cause. |
| Americano | Espresso expression after dilution; aroma, strength, taste structure, body, and whether water and coffee feel joined | use espresso families, plus clean, open, diluted, watery | Record shot-to-water ratio and temperature if known. A dedicated universal professional target is not established. | Strength, clarity, water-coffee integration, finish. “Does it feel intentionally light, or thinner than you wanted?” |
| Pour-over and drip | Aroma definition, sweetness, sourness/acidity character, broad flavor family, clarity, body, finish, cooling change | citrus, orchard fruit, berry, tropical, floral, honey, cocoa, nut, cereal, tea-like, herbal | Paper filtration can affect oils and body, but recipe and coffee matter. “Clarity” means sensations are easy to distinguish, not automatically better. | Aroma, sweetness, acidity shape, clarity, body, finish, temperature change. Ask about papery, stale, hollow, harsh, or unexpectedly smoky notes without assigning extraction causes. |
| Immersion and French press | Integrated flavor, strength, sweetness, sour/bitter structure, body, coating, sediment or particles, finish | the shared coffee families, plus rounded, dense, oily, silty, coating | Metal filtration and fines can produce more body or sediment in some preparations; this is neither inherently good nor bad. | Body, texture, coating, clarity, finish. Ask “Is the sediment pleasant, neutral, or distracting?” |
| Cold brew | First identify cold-extracted versus hot-brew-chilled, concentrate versus ready-to-drink, and ice/dilution. Notice aroma, sweet impression, sourness, bitterness, floral/fruit/roast character, body, finish | floral, fruit, cocoa, caramel, roast, rubber-like, smooth, syrupy, clean | Controlled studies show differences by extraction temperature, origin, and roast, but “cold brew is always sweeter and less acidic” is not defensible. | Extraction style, dilution, aroma, taste structure, body, finish. Ask what changes as ice melts. |
| Latte, cappuccino, flat white, cortado, and other milk coffee | Milk sweetness, coffee expression, integration, temperature, body, foam texture, finish | dairy, cereal, oat, nut, coconut, caramel, vanilla, cocoa, coffee/roast | Separate liquid thickness from foam texture. Fine/velvety, airy, bubbly, dry, stable, or quickly fading can all be observations. Drink ratios vary by market. | Coffee presence, milk sweetness, integration, foam texture, temperature, finish. Ask whether the drink feels joined or layered, not whether milk “hides flaws.” |
| Sweetened or flavored coffee | Record additions first. Distinguish inherent sweet impression from added sweetness; notice base-coffee presence, flavor accuracy, integration, body/coating, and sweetener finish | ingredient-specific families plus syrupy, candied, creamy, cooling, spicy | Sugar and sweeteners change taste and cross-modal aroma perception. The coffee may intentionally be secondary. | Sweetness intensity, base identity, ingredient integration, coating, aftertaste. “Is the sweetness where you want it?” is preference, not an objective defect score. |
| Matcha | Dry aroma, powder color as observation, dispersion, foam if whisked, umami, sweet impression, bitterness, astringency, smoothness versus grit, finish | leafy, green, floral, nori/seaweed, broth-like, malt, nut, cocoa | Matcha is a suspension. Capture fine/silky, chalky, gritty, coating, airy/creamy foam, and settling. Professional evaluation values bright color, fine particles, stable fine foam, smoothness, and harmony, but each must remain separate from enjoyment. | Color, aroma, umami, bitterness, astringency, suspension, texture, foam, finish. Ask about dull color, stale/cardboard aroma, clumping, coarse grit, or one-note harshness without diagnosing age or grade. |
| Hojicha | Roast degree; sweet, green, woody, and toasted aroma balance; bitterness, astringency, body, finish; leaf versus powder | toast crust, roasted barley, toasted rice, roasted nut, caramel, cocoa, wood, faint green leaf | Leaf hojicha may feel light and clean; powder can be fuller and particulate. Dark roast can intentionally emphasize char or smoke. | Roast character, sweetness, green/woody character, dry grip, body, finish. Ask whether char, ash, acrid smoke, staleness, sourness, or thinness exceeds the user's expectation. |
| Green tea | Fresh/vegetal versus pan-fired or roasted character; umami, sweet impression, bitterness, drying grip, finish | steamed greens, spinach, edamame, fresh herb, nori, chestnut, grain, toast, floral, citrus | Often light to brothy or rounded, with widely variable bitterness and astringency. Temperature effects should be observed rather than predicted. | Aroma style, umami, bitterness, astringency, body, finish, infusion change. Cooked, scorched, ashy, musty, leathery, or stale may be unexpected for one style and intentional in another. |
| Black tea | Malt/grain versus fruit/floral character; sweetness, bitterness, drying structure; finish | malt, cereal, bread crust, honey, caramel, dried fruit, citrus peel, flower, spice, wood, smoke | Light to full; smooth, lively, drying, or coating. Explain “brisk” in plain language rather than treating it as a universal virtue. | Aroma, sweetness, bitterness, astringency, body, finish, milk integration if relevant. Ask about flat, papery, stale, stewed, sour/fermented, musty, scorched, or smoky relative to style. |
| White tea | Subtle versus absent aroma; fresh/green versus floral/fruity/sweet character; delicate or evolving finish; style and age | fresh leaf, hay, straw, white flower, pear, melon, stone fruit, honey, dried fruit | Commonly light or silky, but mature-leaf and aged styles can be fuller. Subdued aroma is not automatically a fault. | Aroma, sweetness, bitterness/astringency, softness, finish. Ask about stale/papery, musty, mold-like, or unexpectedly sour notes while allowing intentional hay and oxidation character. |
| Oolong | Confirm style first: fresh/floral, honeyed/fruity, or roasted/deep. Notice aroma persistence and roast integration | leaf, blossom, peach, ripe fruit, honey, cream association, toasted grain, nut, caramel, cocoa, wood | Oolong spans a very broad oxidation and roast spectrum. Body may feel rounded, silky, creamy, structured, or drying. | Style, aroma, sweetness, roast, body, astringency, finish. Ask whether roast overwhelms the other sensations for this user rather than enforcing one ideal. |
| Herbal infusions | Identify the botanical or blend before suggestions. “Herbal” is not one flavor family. | floral, fresh herb, dried herb, mint/cooling, citrus, spice/warming, root/earth, fruit/tart, ingredient-specific terms | Can be thin, juicy, syrupy, mucilaginous, drying, warming, or cooling. Ingredient packs should drive suggestions. | Ingredient identity, aroma, sour/sweet/bitter structure, body, finish. Stale/dusty, musty/mold-like, soapy, perfumy, medicinal, or foreign chemical notes need context; possible contamination receives a safety message, not a low score. |
| Milk tea | Tea presence, milk character, sweetness, integration, thickness, add-in texture, finish | tea/malt/floral/roast; dairy/cereal/nut/coconut/oat; caramel, vanilla, spice, fruit | Watery to thick; slippery, creamy, coating, chalky, or drying. Milk, sugar, temperature, and tea chemistry interact. | Tea presence, milk identity, sweetness, integration, body, coating, finish. Ask about separation, curdling, watery texture, powderiness, stale dairy, or a longer sweetness finish than desired. |
| Home recipe and user-defined drink | Let the user confirm base, preparation, temperature, milk, sweetener, and additions; then compose packs | universal broad families plus user-authored words | Use universal aroma, taste, mouthfeel, finish, integration, and preference dimensions when identity is unknown. Never force a specific family. | Universal pack plus confirmed modifier overlays. “Something else” and custom criteria are first-class, not failure states. |

### Everyday reference examples

References are optional memory aids, not professional standards:

| Sensation | Possible everyday references |
| --- | --- |
| Green/vegetal | cucumber peel, steamed spinach, asparagus, edamame |
| Marine | dry nori or plain seaweed |
| Floral | jasmine, rose, honeysuckle, or another flower the user knows |
| Fresh fruit | apple, pear, peach, citrus peel |
| Dried fruit | raisin or dried apricot |
| Malt/grain | malt cereal, bread crust, toasted barley |
| Roast | toasted rice, toast crust, roasted nuts, cocoa nib |
| Umami | weak kombu water, plain broth, or a dilute MSG reference |
| Bitter | unsweetened cocoa or tonic water |
| Astringent | the drying after strong unsweetened black tea or a red-grape skin; this is a feeling, not the grape flavor |
| Light to full | water, skim milk, and whole milk as conceptual body anchors |
| Smooth to particulate | a well-dispersed powder drink versus a visibly clumped one |

Reference records need allergen, dietary, cultural-familiarity, availability, and locale metadata. Users should be able to replace an unfamiliar reference with one meaningful to them.

## 4. Mugshot sensory taxonomy

The taxonomy should be original, compact, hierarchical, stable by ID, and independent of its current display language.

### 4.1 Observation sequence

1. **Identity and context**
   - beverage family;
   - preparation;
   - hot, warm, iced, frozen, or cold-extracted;
   - milk, sweetener, flavor, and add-in modifiers;
   - recipe context if known;
   - parser confidence and user confirmation.
2. **Appearance when relevant**
   - color;
   - clarity or opacity;
   - crema;
   - foam;
   - suspension, particles, or settling.
3. **Aroma before the sip**
   - overall intensity;
   - broad family;
   - optional specific descriptor.
4. **First-sip taste structure**
   - sweet impression;
   - sourness/acidity;
   - bitterness;
   - saltiness and umami only when relevant.
5. **Flavor aroma during and after the sip**
   - broad family first;
   - optional child term;
   - custom user language always allowed.
6. **Mouthfeel**
   - weight/body;
   - flow/viscosity;
   - lubrication;
   - particulate texture;
   - coating;
   - astringency subtype;
   - foam texture when relevant.
7. **Finish**
   - residual aroma;
   - residual taste;
   - residual mouthfeel;
   - duration and trajectory.
8. **Structure**
   - clarity: “Can you distinguish the sensations?”
   - integration: “Do the parts feel joined or separate?”
   - balance: “Does anything dominate for you?”
   - overall intensity.
9. **Personal response**
   - personal rating;
   - would order again;
   - optional quality impression;
   - confidence;
   - personal note or memory.

### 4.2 Broad descriptor families

These families intentionally do not reproduce the structure, wording, or full inventory of an existing wheel:

- **Fruit**
  - citrus;
  - orchard;
  - berry;
  - tropical;
  - stone fruit;
  - dried fruit.
- **Floral**
  - fresh blossom;
  - perfumed;
  - tea-floral.
- **Sweet and browned**
  - honey;
  - caramel;
  - brown sugar or molasses;
  - vanilla;
  - confection-like.
- **Nut and cocoa**
  - almond-like;
  - peanut-like;
  - roasted nut;
  - cocoa;
  - dark chocolate.
- **Grain and malt**
  - fresh grain;
  - cereal;
  - malt;
  - bread;
  - toasted grain.
- **Roast and smoke**
  - toasted;
  - roasty;
  - smoky;
  - charred;
  - ashy.
- **Green and botanical**
  - fresh leaf;
  - steamed greens;
  - herb;
  - grass;
  - marine;
  - root.
- **Spice**
  - warm spice;
  - pepper-like;
  - cooling spice;
  - aromatic spice.
- **Fermented and savory**
  - tangy fermentation;
  - wine-like;
  - vinegar-like;
  - broth-like;
  - soy-like.
- **Earth and wood**
  - fresh earth;
  - musty earth;
  - cedar-like;
  - dry wood;
  - tobacco-like.
- **Dairy and ingredient contribution**
  - dairy;
  - cereal milk;
  - plant milk;
  - syrup;
  - fruit addition;
  - spice addition.
- **Unfamiliar or unexpected**
  - papery/stale;
  - mold-like;
  - medicinal/phenolic;
  - rubber-like;
  - metallic;
  - chemical;
  - custom wording.

Terms such as roast, smoke, earth, marine, bitterness, sour fermentation, and astringency are not globally classified as faults. Applicability and expectation depend on beverage, style, preparation, and the user's intent.

### 4.3 Mouthfeel model

Body is not a sufficient mouthfeel model:

| Dimension | Beginner anchors | Storage semantics |
| --- | --- | --- |
| Weight/body | light, medium, full | independent ordinal intensity |
| Flow/viscosity | watery, flowing, thick, syrupy | categorical plus optional intensity |
| Lubrication | slippery, smooth, drying | categorical; can coexist with body |
| Particulate texture | silky, fine, chalky, gritty | multi-select observation with intensity |
| Coating | clean, lightly coating, mouth-coating | ordinal intensity |
| Astringency subtype | dry, rough, puckering, velvety grip | multi-select tactile observation |
| Foam | airy, creamy, fine, coarse, stable, fading | beverage-specific observation |
| Finish trajectory | fades, lingers, blooms, changes, builds | categorical plus optional duration |

### 4.4 Unexpected-note and safety model

“Fault” should not be a flat descriptor parent. Store one of:

- unexpected for this style;
- possibly preparation-related;
- possibly storage-related;
- intentional or style-dependent;
- personal dislike only;
- possible safety concern.

Mold-like aroma, foreign chemical odor, spoiled dairy, or visible contamination should invoke a gentle safety-oriented message. They should not simply lower a sensory score.

## 5. Proposed scoring and scale semantics

### 5.1 Presence and response state

Every observation supports an explicit state:

| State | Meaning | Analytics rule |
| --- | --- | --- |
| Unanswered | No response yet | no evidence |
| Present | User noticed it | evidence, optionally with intensity |
| Not present | User actively did not notice it | negative observation evidence; never preference |
| Not sure yet | User cannot decide | uncertainty; never serialize as absence |
| Skip | User chose not to answer | no sensory evidence |
| Not relevant | Criterion does not apply | no sensory evidence; retain applicability context |

“Not sure yet,” Skip, and Not relevant must never be represented by zero. Zero must not carry multiple meanings.

### 5.2 Intensity

Default consumer intensity uses three anchored steps with no half values:

| Value | Label | Anchor |
| --- | --- | --- |
| 1 | Low | “Subtle; I notice it when I look for it.” |
| 2 | Medium | “Clear; it shares the sip with other sensations.” |
| 3 | High | “It leads the sip or lingers.” |

The UI must state: **High intensity is not automatically better.**

Deep mode may offer a five-step scale after research validation:

1. trace;
2. gentle;
3. clear;
4. strong;
5. dominant.

Mugshot should not expose a professional-style 0–15 scale without reference preparation, panel training, and a use case that genuinely needs that resolution.

### 5.3 Confidence

Confidence is categorical and does not alter the displayed sensory value:

- **I'm still learning**
- **Maybe**
- **I'm sure**

For analytics, confidence may change how cautiously Mugshot phrases a future pattern. It must not change personal rating, quality impression, or the validity of the user's experience.

### 5.4 Personal preference

The current star control can remain for Quick Rating, but it must be relabeled as personal enjoyment and explain every half step:

| Rating | Plain-language anchor |
| --- | --- |
| 1.0 | Not for me |
| 1.5 | Mostly not for me |
| 2.0 | More misses than hits |
| 2.5 | Mixed |
| 3.0 | Enjoyed it |
| 3.5 | Really enjoyed it |
| 4.0 | Would order again |
| 4.5 | Memorable; I would seek it out |
| 5.0 | A personal favorite |

Half steps remain here because Mugshot already supports them and returning users may compare close personal experiences. They should not be used for low/medium/high sensory intensity.

### 5.5 Optional quality impression

Quality impression should be:

- absent from Quick mode;
- off by default in Guided mode;
- optional in Deep mode;
- labeled “How well did this drink work for its intended style?”;
- separate from enjoyment and intensity;
- anchored with whole steps, not half steps;
- excluded when the user does not know or care about the intended style.

This is a personal quality impression, not CVA, Q grading, or a claim of objective quality.

### 5.6 Overall Mugshot score

The overall score should remain the user's independent personal rating.

It should **not** be:

- a weighted average of sensory criteria;
- derived from descriptor count;
- increased by confidence;
- decreased by “not sure” responses;
- compared across users as if calibrated;
- presented as beverage quality.

The Taste Snapshot may summarize “bright citrus, medium body, drying finish, 4.0 personal rating,” but it should not calculate a second composite.

## 6. Example educational prompts and tooltips

### Bias-reducing first observation

- **Prompt:** “Before the labels, what stands out?”
- **Helper:** “Your own words are enough. You can also choose ‘not sure yet.’”
- **Why:** “Suggestions can influence what people select, so Mugshot starts with your impression.”

### Aroma and flavor

- **Prompt:** “What reaches your nose before the sip?”
- **Tooltip:** “Aroma before sipping travels in through your nose. Aroma can also return behind your nose while you sip or breathe out afterward.”
- **Action:** “After swallowing, breathe out gently through your nose. Did anything new appear?”

### Sweetness

- **Prompt:** “How strong is the sweet impression?”
- **Tooltip:** “Coffee and unsweetened tea can feel sweet even when they contain very little sugar. Added sweetness is recorded separately.”

### Sourness and acidity

- **Prompt:** “Does the sour side feel gentle, juicy, sharp, or not present?”
- **Tooltip:** “Sourness is a taste. ‘Acidity’ is often used more broadly for a bright or lively structure. Strength and enjoyment are separate.”

### Bitterness

- **Prompt:** “How strong is the bitterness?”
- **Tooltip:** “Bitterness can feel cocoa-like, tea-like, roasty, or sharp. First record its strength; then decide whether you enjoy how it fits.”

### Astringency

- **Prompt:** “A few seconds after the sip, do your cheeks, gums, or tongue feel drier?”
- **Tooltip:** “Astringency is a drying or gripping mouthfeel, not bitterness.”

### Body and texture

- **Prompt:** “What does it feel like in motion?”
- **Choices:** light, flowing, creamy, thick, syrupy, not sure yet.
- **Follow-up:** “Now separate that from texture: silky, fine, chalky, gritty, smooth, or drying.”

### Finish

- **Prompt:** “Ten seconds later, what remains?”
- **Choices:** aroma, taste, dryness/coating, nothing clear, not sure yet.
- **Tooltip:** “A finish can fade, linger, bloom, change, or build. Long is not automatically better.”

### Temperature

- **Prompt:** “As it changes temperature, what changes for you?”
- **Choices:** aroma, sweetness, sourness, bitterness, texture, nothing I can name.
- **Tooltip:** “There is no required answer. Different drinks and people change in different ways.”

### Espresso

- **Prompt:** “Notice the crema, then stir once if you want. Does the sip itself change?”
- **Tooltip:** “Crema can affect aroma release and expectation. It is not a score of espresso quality.”

### Milk coffee

- **Prompt:** “Do coffee and milk feel joined, layered, or hard to separate?”
- **Tooltip:** “Integration describes how the parts fit together. It does not require strong coffee or a specific milk ratio.”

### Matcha

- **Prompt:** “Does the suspension feel silky, fine, chalky, or gritty?”
- **Tooltip:** “Matcha is powdered tea suspended in water. Color, foam, texture, umami, bitterness, and astringency are separate observations.”

### Hojicha

- **Prompt:** “Where does the roast sit: gentle toast, clear roast, dark char, or not sure?”
- **Tooltip:** “Roast can bring sweet, nutty, woody, green, smoky, or charred impressions. Darker is not automatically better.”

### Tea

- **Prompt:** “What remains longer: aroma, bitterness, or dry grip?”
- **Tooltip:** “Tea aroma, bitter taste, and astringent mouthfeel can follow different timelines.”

### Learning-oriented confidence

- **Prompt:** “How sure are you?”
- **Choices:** I'm still learning, Maybe, I'm sure.
- **Tooltip:** “This helps Mugshot phrase your snapshot carefully. It does not grade your palate.”

## 7. Deterministic suggestion system

The default system should be local, inspectable, and deterministic. Suggestions are prompts to investigate, never claims about what the drink contains.

### 7.1 Selection pipeline

1. **Normalize the confirmed drink identity.** Parse beverage family, preparation, serving temperature, milk, sweetener, flavor additions, and relevant recipe details. Keep a confidence value and provenance for each field.
2. **Ask for correction when identity is uncertain.** A user can change “latte” to “flat white,” “iced coffee” to “cold brew,” or “green tea” to “matcha” before the system chooses a pack.
3. **Choose one base pack.** The confirmed family and preparation select a versioned base such as `coffee.pour_over`, `coffee.espresso`, `tea.matcha`, or `tea.hojicha`.
4. **Apply factual overlays.** Temperature, milk, sweetener, flavored syrup, powdered preparation, and other confirmed additions add or suppress relevant prompts. They do not silently change the user's overall rating.
5. **Apply the selected depth.** Quick uses a small core; Guided adds sequence and explanation; Deep exposes the full applicable set and optional quality impression.
6. **Collect a neutral observation first.** The first free response appears before descriptor suggestions to reduce priming.
7. **Rank the remaining prompts.** Rank by the current sensory stage, pack relevance, explicitly saved criteria, and repeated confirmed use for the same beverage scope. Do not rank a descriptor highly because it appeared once or because AI guessed it.
8. **Fall back safely.** An unknown drink receives the universal pack: aroma, sweet/sour/bitter/umami/salty impressions, body, texture, astringency, finish, temperature change, and personal rating. This works offline.
9. **Explain and allow correction.** A suggestion can say “Shown because this is a latte” or “Shown because you often record texture for matcha.” The user can dismiss it, edit the drink identity, or choose “not sure yet.”

The deterministic ranker should use stable IDs and explicit rules, not a hidden “palate score.” A practical first release can use ordered rule matches rather than opaque weights.

### 7.2 Personalization without reinforcement loops

Personalization should model the user's habits, not declare their sensory ability.

- Keep **noticed**, **intensity**, **liked**, and **confidence** as distinct evidence.
- Require repeated, confirmed observations in the same beverage scope before promoting a descriptor. A reasonable beta threshold is three separate tastings, then validate that threshold with users.
- Give less evidentiary weight to “Maybe,” AI-suggested-and-unconfirmed, or system-prompted selections than to spontaneous confirmed notes.
- Show the evidence behind a learned prompt, for example “You noticed citrus in 4 of 6 recent pour-overs.”
- Offer “This is not useful” and “I selected that by mistake” controls that remove or down-weight evidence.
- Never infer “expert,” “beginner,” “good palate,” or “bad palate” from vocabulary size, rating consistency, confidence, or uncertainty.
- Never turn repetition into a requirement. “Try something different” can be educational, but the system must not penalize familiar preferences.

### 7.3 Optional constrained AI enhancement

AI is an enhancement to the deterministic system, not a source of sensory truth.

Allowed first use:

- map user-authored notes such as “orange peel and a little drying” to an allowlisted taxonomy candidate (`citrus.orange_peel`, `mouthfeel.astringent`) while preserving the original words;
- retrieve the exact curated explanation and source reference for those candidates;
- ask the user to confirm or reject the mapping.

Required controls:

- strict structured output with only known bundle IDs;
- server- and client-side validation against the active bundle version;
- recorded model, model version, confidence, provenance, and user confirmation;
- no invented descriptors, scientific claims, scores, or professional calibration language;
- no automatic change to a personal rating, quality impression, or taste profile;
- no implicit transmission of private captions, photos, location, or unrelated history;
- a clear offline and validation-failure fallback to the deterministic pack;
- an accessible explanation of why the prompt appeared and an easy correction path.

Later AI experiments may summarize a user's confirmed observations, but only from snapshot data the user can inspect. They should say “You often recorded…” rather than “Your palate is…”.

## 8. Data model, persistence, and backend implications

### 8.1 Versioned offline knowledge bundle

Ship sensory knowledge as a bundled, reviewable JSON resource, loaded through a typed `SensoryKnowledgeBundle`. The bundle should include:

- bundle ID, schema version, content version, locale, publication date, and review date;
- stable descriptor IDs, parent paths, plain-language labels, sensory dimensions, and synonyms;
- beverage packs and deterministic applicability rules;
- scale IDs, exact anchors, prompt copy, tooltips, and accessibility labels;
- source references, source type, evidence status, attribution, and license notes;
- deprecation and replacement metadata so old IDs remain interpretable.

Copy should be original and plain-language. The WCR lexicon, SCA materials, scientific papers, and supplied flavor wheel inform the structure; Mugshot should not reproduce a proprietary wheel, reference list, artwork, or wording wholesale.

### 8.2 Immutable response snapshots

The runtime model should distinguish at least:

- `TastingDepth`: quick, guided, deep;
- `SensoryDimension`: aroma, taste, flavor, body, texture, astringency, finish, temperature change, balance/integration, fault observation;
- `ResponseState`: notAsked, skipped, notPresent, unsure, observed;
- `SipSensoryResponseSnapshot`;
- `SipSensorySnapshot`.

Each saved response snapshot should carry enough meaning to survive future wording and taxonomy changes:

- criterion and descriptor stable IDs;
- displayed label and hierarchy snapshots;
- sensory dimension;
- response state;
- intensity, preference, optional quality impression, and confidence as separate nullable values;
- custom text in the user's original words;
- scale ID, scale version, and displayed anchor snapshots;
- bundle ID and content version;
- source pack, suggestion origin, and displayed order;
- AI model/version/confidence/provenance only when AI participated;
- explicit user-confirmation state.

The parent `SipSensorySnapshot` should include the confirmed drink identity snapshot, tasting depth, ordered responses, the independent personal overall rating, creation time, and schema version. Saving a visit freezes this object. Later bundle changes must not reinterpret it.

### 8.3 Compatibility with the current app

Keep the current visit-level `overall_score` as the personal Mugshot rating. Do not derive it from the new observations.

Legacy visits can continue to render their stored criterion name/score/weight snapshot. New visits should dual-write a display-compatible projection only while older clients require it, and read the versioned sensory snapshot when present. Legacy weighted criteria should be labeled as legacy rather than silently converted into intensity or quality.

Saved criteria and personalization evidence are mutable account preferences and must be stored separately from immutable visit snapshots. A historical visit should not change when a preference is renamed or deleted.

### 8.4 Backend outline

A first backend shape can use an owner-only one-to-one `visit_sensory_snapshots` table:

- `visit_id` primary key and foreign key;
- `user_id` for direct row-level security checks;
- `schema_version`, `bundle_id`, `bundle_version`, and `mode`;
- confirmed drink identity JSON;
- ordered sensory response JSON;
- independent personal rating mirror if needed for consistency checks;
- an explicitly chosen, minimal public projection JSON;
- `created_at`.

Enforce insert-once behavior with grants and a trigger or equivalent database invariant; application convention is not sufficient. Owners may read the full snapshot. Social readers should see only fields deliberately projected for sharing. Any future edit should create an explicit revision or correction event rather than rewriting history invisibly.

The existing taste-graph aggregation must also be versioned. It currently treats every rating category as a generic sensory evaluation and averages stored scores. The new graph should distinguish observation, intensity, preference, confidence, and personal overall rating, and should never average them into a composite “taste ability” signal.

Migration work must include:

- dual-read behavior and retry/idempotency for offline saves;
- row-level security tests for owner, follower, stranger, and blocked-user cases;
- account export and deletion coverage for snapshots and personalization evidence;
- bundle-version fixtures so old snapshots remain readable;
- explicit privacy defaults for captions, free text, AI processing, and public projection.

## 9. Current Tasting Lens audit

This is a Tier 0, read-only evidence audit of the pinned repository and its accepted checkpoint captures. It is not a fresh Simulator accessibility or end-to-end run.

### 9.1 Existing journey

The current composer offers a Quick path or Tasting Lens, then renders a repeated star row for each criterion. A criterion editor can add, rename, reorder, delete, and weight criteria. Completing that editor saves the template globally. The saved visit freezes criterion name, score, weight, order, and relevance; the overall score is then calculated as a weighted average.

Relevant code evidence:

- snapshot fields: [`SipDraft.swift`](../testMugshot/Models/SipDraft.swift);
- weighted calculation: [`SipDraft.swift`](../testMugshot/Models/SipDraft.swift);
- Tasting Lens rows and criterion editor: [`SipComposerView.swift`](../testMugshot/Views/Add/SipComposerView.swift);
- device-local template persistence: [`DataManager.swift`](../testMugshot/Services/DataManager.swift);
- remote flattening into name/score/weight: [`VisitService.swift`](../testMugshot/Services/Supabase/VisitService.swift);
- current taste-graph aggregation: [`20260714130000_phase_3_explainable_taste_graph.sql`](../supabase/migrations/20260714130000_phase_3_explainable_taste_graph.sql).

Visual evidence:

- [accepted Tasting Lens checkpoint](../../../../.codex/visualizations/2026/07/13/019f5bda-9c1e-7a62-b883-3031550aa18e/phase-0-sipping-loop/03b-tasting-lens-device-stable.png);
- [accepted Quick checkpoint](../../../../.codex/visualizations/2026/07/13/019f5bda-9c1e-7a62-b883-3031550aa18e/phase-0-sipping-loop/03-quick-rating-private-save-device.png).

### 9.2 What is already strong

- Quick remains available, so deeper tasting is optional.
- The composer has a coherent guided shell, clear progress, and a stable save affordance.
- Draft persistence and repeat/idempotent visit behavior provide a useful foundation.
- Saved criteria use snapshots, so a later template rename does not already rewrite the displayed historical label.
- Suggestions are positioned as optional and the existing semantic-tag foundation can support a controlled migration.
- Taste Identity already distinguishes repeated evidence and exposes correction-oriented interaction patterns.
- Drink analysis already has schema/version/confidence/provenance concepts and override support.
- The cream canvas, editorial serif, restrained sage/mint palette, rounded cards, and organic `MugshotTasteBloom` provide a recognizable system without requiring a conventional flavor wheel.

### 9.3 Friction and risk

- Repeating the same star mechanic makes aroma, sweetness, body, and balance appear to mean the same thing.
- Editable weights imply precision and culminate in a composite that can be mistaken for objective quality.
- `N/A` cannot distinguish not present, not noticed, unsure, skipped, or not applicable.
- Blank custom criteria and unrestricted renaming lose semantic meaning.
- Saving criterion edits globally from a visit can produce accidental future defaults.
- The backend flattens category snapshots and cannot preserve scale semantics, prompt version, taxonomy path, or confidence.
- The current database does not enforce immutable sensory snapshots.
- Taste-graph aggregation interprets unlike scores as one signal.
- Drink-family parsing is not yet a confirmed, granular pack selector, and duplicated local/edge analysis versions can drift.
- A long run of similar star controls increases cognitive and motor repetition. Small secondary actions and a fixed footer also warrant Dynamic Type, VoiceOver order, contrast, and keyboard/scroll validation when implementation begins.
- A wheel-first experience would front-load jargon and priming. The supplied Counter Culture image is useful as a vocabulary reference, not as a screen architecture to copy.

## 10. Product principles and ethical safeguards

1. **Observe before suggesting.** Start in the user's words, then reveal optional structure.
2. **Describe before evaluating.** Presence, intensity, preference, confidence, and optional quality impression remain separate.
3. **Personal, not professional.** Mugshot supports memory and learning; it does not issue Q scores, calibration claims, or certifications.
4. **Beverage-aware and user-correctable.** Packs reflect preparation and additions, while the user remains the authority on what they are drinking.
5. **Progressive depth.** Quick, Guided, and Deep share one model without forcing every user through expert detail.
6. **Uncertainty is legitimate data.** “Not sure yet” is useful and never lowers a score.
7. **Offline knowledge is the source of truth.** AI cannot invent the taxonomy or block the flow.
8. **Historical meaning is frozen.** Versioned snapshots outlive copy and bundle changes.
9. **Personalization shows its evidence.** Users can inspect, dismiss, and correct learned suggestions.
10. **Compare experiences, not people.** Trends are framed within a user's own history and beverage context.
11. **Accessibility is structural.** Controls need non-color state, plain labels, generous targets, logical VoiceOver order, Dynamic Type behavior, reduced-motion support, and a path that does not depend on a flavor map.
12. **Mugsy is a restrained guide.** Use the canonical white mug with glasses and right-side handle at occasional teaching moments, never as a persistent judge, streak enforcer, or emoji substitute.

The system should not use streak loss, urgency, shame, public ranking, hidden scoring, “palate level,” vocabulary-count rewards, or notifications that pressure a user to drink caffeine or alcohol. Health or safety observations should be shown as safety guidance, not folded into taste quality.

## 11. Phased implementation plan

No phase below begins until one of the three experience concepts and its state sheet are explicitly approved.

### Phase 0 — experience approval

- Select or refine one 390×844 concept.
- Produce the selected screen's state sheet: default, unsure, not present, error, offline, large text, VoiceOver, reduced motion, and save/retry.
- Confirm where Quick, Guided, and Deep are entered and exited.

### Phase 1 — knowledge foundation

- Add the typed, versioned offline bundle and source registry.
- Define stable IDs, dimensions, response states, scales, packs, overlays, and validation.
- Add focused decoding, bundle-version, rule-selection, and fallback tests.

### Phase 2 — domain and persistence

- Add immutable snapshot models without changing the existing personal overall score.
- Implement legacy dual-read and temporary compatible projection.
- Add backend insert-only enforcement, owner-only full snapshot access, explicit public projection, export/deletion, and RLS tests.

### Phase 3 — Quick and identity confirmation

- Confirm or correct drink identity.
- Replace the undifferentiated star sequence with a small set of correctly anchored controls.
- Preserve one-tap uncertainty and an obvious return to Quick.

### Phase 4 — Guided core journey

- Implement neutral first observation, aroma/flavor, taste structure, body/texture/astringency, finish/temperature, and independent personal rating.
- Add original tooltips and beverage-specific packs for the priority set: pour-over, espresso, cold brew/iced coffee, milk coffee, matcha, hojicha, and tea.

### Phase 5 — Deep mode and customization

- Add optional quality impression, advanced subdimensions, custom observations, and saved criteria with semantic guardrails.
- Verify all approved state-sheet conditions and accessibility behaviors.

### Phase 6 — Taste Snapshot and personalization

- Render an evidence-backed, plain-language snapshot from the immutable record.
- Add same-user, same-scope comparison with support counts and correction controls.
- Validate promotion thresholds and bias language through moderated tests.

### Phase 7 — constrained AI experiment

- Add allowlisted mapping of user-authored notes behind a feature flag.
- Log provenance and confirmation; measure rejection, correction, and fallback rates.
- Do not launch if AI reduces trust, changes ratings, or creates unsupported claims.

### Phase 8 — beta and release validation

- Test comprehension across coffee, tea, matcha, milk, decaf, sweetened, and unknown drinks.
- Validate offline saves, retries, concurrency, privacy, migrations, accessibility, and social projections at the verification tier required by repository policy.
- Review citations, bundle licenses, and professional-language boundaries before release.

## 12. Open research questions and approval gate

Questions to resolve with prototypes and user testing:

- Which consumer intensity anchors remain understandable across coffee and tea without implying objective calibration?
- Should aroma and flavor vocabulary be localized by synonym while stable IDs stay language-neutral?
- When should the app ask for cooling checkpoints, and when would that create too much ceremony?
- Is three confirmed tastings the right threshold for learned prompts, or should it vary by evidence type?
- Which snapshot fields, if any, should be shareable by default versus explicitly selected each time?
- Does an optional quality-impression scale help learning, or does it recreate the current composite-score confusion?
- Which external taxonomy elements have reusable licenses, and which must remain citation-only inspiration?

The next gate is visual concept selection, followed by approval of the selected concept's full state sheet. Production code is intentionally out of scope until both approvals are explicit.
