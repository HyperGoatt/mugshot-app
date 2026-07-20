# Mugshot V3 Product Interview

**Status:** Locked product-direction record, with unresolved alpha hypotheses called out explicitly

**Interview completed:** July 20, 2026

**Owner:** Joe Rosso, creator of Mugshot

**Purpose:** Preserve the full eight-round product interview that established Mugshot V3 before implementation work begins.

This document is the durable source of truth for the V3 logging direction. It records the questions, Joe's substantive answers, and the resulting product decision after each answer. It should be read before changing Log a Sip, cafe reflection, home recipes, setting reflection, publishing, Taste Passport, notifications, or alpha analytics.

## How to read this record

- **Joe's answer** preserves the intent and substantive detail of the spoken answer. Repetition and speech-to-text artifacts have been lightly cleaned for readability.
- **Agreed decision** records the interpretation Joe explicitly approved in the following round or later clarification.
- **Unresolved** means the interview deliberately left the decision for research, design validation, policy work, or alpha evidence.
- Nothing marked as an alpha hypothesis should silently become a permanent rule.
- All product copy uses `cafe` and `cafes` without an accented character, per repository policy.

## The product direction that emerged

Mugshot V3 is a **journal-first, social-second memory ritual**, not a professional cupping form and not a public review marketplace. It should help someone pause while they are drinking, notice the sip and setting, preserve their honest reaction, and optionally share a cleaner expression of that memory with friends.

The target experience supports two equally valid behaviors:

1. A casual user can add a visual, drink name, caption, sip score, context, and audience, then publish in under a minute.
2. A reflective user can spend several minutes adding a private raw note, criteria, importance, flavor exploration, a cafe or setting reflection, and recipe details without entering a separate "deep" flow.

Guided and Deep modes are therefore retired as primary choices. Depth is progressive, optional, and available on the same reflection surfaces.

## Locked five-screen flow

The approved V3 is five screens, not a two-screen end-to-end flow. "Two surfaces" refers only to the two reflection canvases.

1. **Log a Sip setup**
   - Select `Cafe`, `Home`, or `Elsewhere` first.
   - Add one or more photos, or deliberately choose the Mugsy "I missed the photo" placeholder.
   - Choose the cover photo.
   - Add the drink name.
   - For Cafe, select the cafe. Home and Elsewhere adapt to their context.
   - Draft state is visible and autosaved.

2. **How was the sip?**
   - Optional private raw journal note.
   - User-owned overall sip score.
   - Optional suggested or custom criteria, each with its own evaluative star rating.
   - Optional human-language importance: Less, Normal, More, or Most.
   - Optional "Use last setup" and pinned criteria.
   - Optional Mugsy thinking prompts and interactive flavor explorer.
   - If several drinks belong to the visit, "Add another drink" adds another sip card on this surface.

3. **How was the cafe? / home or setting context**
   - Cafe: optional raw journal reflection, cafe score, optional criteria, importance, and Mugsy prompts.
   - Home: recipe and repeatability support; the making process is evidence for the sip, not another rating.
   - Elsewhere: named setting, optional reflection, and optional setting score.
   - A seated cafe visit requires at least a cafe score. To-go can omit cafe reflection. Home recipe detail and Elsewhere setting reflection remain optional.

4. **Publish Mugshot**
   - Full-screen review, not a slide-up card.
   - Cover, drink name, place/context, and date.
   - Required caption.
   - Sip, cafe/setting when present, and blended Mugshot score.
   - Audience: Private, Friends, or Everyone.
   - Separate raw-note visibility that can never be broader than the post audience.
   - Invite friends into a shared memory.
   - Recipe visibility for Home, private by default.
   - Publish or retain a ready-to-post draft.

5. **Taste Passport**
   - A private, evidence-backed identity summary that grows from logged memories.
   - Uses plain-language patterns, evidence counts, confidence language, criteria, places, and memories.
   - Does not use the rejected radar/web visualization.
   - Explains "Why am I seeing this?"
   - The approved visual direction is passport/city/map based, with language such as "Taking shape," "Early signal," and "Still learning."

## Locked scoring model

### Observation and evaluation are different

A criterion star score means **how well that quality worked for the user**, not how much of the quality was present. For example, "Bitterness 5" means the bitterness worked extremely well for that person; it does not mean the drink was maximally bitter. Descriptive intensity, flavor, aroma, texture, and sequence belong in the raw note, flavor explorer, or descriptive tags.

This preserves the distinction between:

- **What it was:** bright, bitter, thin, floral, quiet, loud, creamy.
- **How it worked for me:** the evaluative star score.
- **How much it mattered this time:** importance.

### The overall score belongs to the user

- Criteria produce an advisory weighted score.
- The overall sip, cafe, or setting score remains whatever the user deliberately chose.
- If criteria suggest 2.3 but the user's felt experience is 4.0, the historical and published score is 4.0.
- Mugshot may quietly show "Your criteria suggest 2.3" with a voluntary `Use 2.3` action.
- Machine learning may suggest or explain; it may never silently change a score.

### The Mugshot score represents the whole memory

- One sip plus one cafe/setting: average the sip and context scores equally.
- Several drinks: first form a blended sip score from the included drinks, then blend that sip result with the single cafe/setting score.
- A 5 sip + 1 cafe and a 3 sip + 3 cafe may both yield a 3 Mugshot. Joe accepts this because Mugshot is a memory of the whole experience.
- Cafe is reflected on once per visit, even when several drinks are logged.
- Home has no artificial cafe score. Its Mugshot score is the sip score unless a future, explicitly tested home-context model is adopted.
- Exact weighting coefficients behind Less, Normal, More, and Most remain an implementation and alpha-validation detail. They should not be exposed as mathematical multipliers in the primary UI.

---

# Round 1 of 8: The V3 foundation

## 1. What should followers see when someone writes a raw brain dump?

**Joe's answer:** The raw brain dump belongs in the journal first. It should be optional on the post. On the final audience page, everyone should have a required caption because captions are cleaner and intentionally composed for friends or the public. The user can keep the raw thought private for memory, or deliberately include it with the post.

**Agreed decision:** Store the raw note as journal content independently from the public caption. Require a caption to publish. Give the raw note its own visibility control, constrained so it can never be shared more broadly than the Mugshot itself.

## 2. What should Mugshot do when someone writes a great entry but has no usable photo?

**Joe's answer:** It can remain a draft until they add a photo. If they truly do not want or forgot to take one, offer a fun Mugsy-style placeholder. A real photo should be highly encouraged.

**Agreed decision:** Do not hold a meaningful journal entry hostage. A visual is required for a published feed card, but the visual may be either a real photo or a deliberately chosen "I missed the photo" Mugsy placeholder. Keep incomplete work safely as a draft.

## 3. If weighted criteria suggest 2.3 but the person's gut says 4, what should the historical score be?

**Joe's answer:** Four. This is their experience and perception, not a mathematical equation. The criteria are there to help. Even if they disliked several components and the criteria calculate to 2.3, they can still decide the experience was a 4 and publish it as a 4.

**Agreed decision:** The explicit overall score is canonical. The weighted result is advisory and may be adopted only through a clear user action.

## 4. Does "Bitterness 5" mean very bitter, or that the bitterness was excellent for that person?

**Joe's answer:** This was a gap. Joe delegated the decision, agreeing that Mugshot should separate what a quality was from how well it worked, with the Specialty Coffee Association value-assessment distinction as useful inspiration.

**Agreed decision:** Criterion stars are evaluative: how well it worked for me. Intensity and sensory description are separate data. The product must explain this in plain language instead of assuming users understand expert scoring semantics.

## 5. Should a 5-sip, 1-cafe visit receive the same Mugshot score as a 3-sip, 3-cafe visit?

**Joe's answer:** Yes. It is a blended experience. A great drink in a terrible cafe should be pulled down by the setting, and a bad drink in an amazing place can be lifted to a memorable 3. Joe wants to test this with friends and family during alpha.

**Agreed decision:** Use a simple equal blend for V3 alpha. Treat perceived misleadingness as an explicit go/no-go hypothesis rather than complicating the formula before testing.

## 6. Do importance weights describe what generally matters to a person or what mattered during this visit?

**Joe's answer:** Both. They describe what mattered during the particular visit and what tends to be important to the person.

**Agreed decision:** Each rating and importance choice is visit-specific. Mugshot may learn cross-visit preferences and suggest previous criteria, but it must not pre-fill a new visit as though the prior rating or importance were already true.

## 7. What should happen to place pages for home, camping, travel drinks, farmers markets, and other non-cafe contexts?

**Joe's answer:** A custom spot may work, but Joe wanted options and ideas before locking the model.

**Agreed decision:** This question remained open in Round 1 and was resolved progressively in Rounds 4 and 5: context begins with Cafe, Home, or Elsewhere; Home is first-class; Elsewhere accepts a flexible setting name and optional reflection; a private home must never expose an address.

## 8. If someone logs three drinks during one visit, should they evaluate the cafe once or three times?

**Joe's answer:** Once. Simple as that.

**Agreed decision:** One visit owns one context reflection. Multiple drinks become multiple sip records inside one Mugshot.

## 9. What is machine learning never allowed to change, infer, or publish on the user's behalf?

**Joe's answer:** It may infer a good bit, but it should never change or publish on their behalf. Machine learning exists to make Mugshot easier and feel like a journal companion.

**Agreed decision:** Suggestions, extraction, ranking, reminders, pattern summaries, and coaching are allowed when transparent and editable. Silent edits, score changes, audience changes, recipe disclosure, and autonomous publishing are prohibited.

## 10. At the end of the first month, which matters most: more published Mugshots, richer taste profiles, or stronger recommendations?

**Joe's answer:** More published Mugshots, definitely. The desired ethical feedback loop is that people visit or make coffee, open Mugshot, log the sip, rate the context, and put a pin on the map. Richer profiles and recommendations are the cherry on top.

**Agreed decision:** Optimize first for completed memories and repeat publishing. Taste intelligence supports expression and return use; it is not the primary outcome.

---

# Round 2 of 8: The person, ritual, and social payoff

## 1. Describe the first person Mugshot should make excited to post repeatedly.

**Joe's answer:** A casual coffee, tea, or matcha drinker, broadly 20-35 and especially upper twenties to early thirties. They care about walkability, enjoy finding new cafes locally and while traveling, and look for the best experiences. The likely audience is city-based, culturally left-leaning, and may skew female because of matcha and tea interest. They already use Instagram and TikTok but are not necessarily influencers. Mugshot should feel like de-influenced social media for them and close friends.

**Agreed decision:** Design for socially active but non-expert casual users first. Specialty depth must be available without making the default feel like expert homework.

## 2. When should someone ideally compose a Mugshot?

**Joe's answer:** While tasting. Ordering and opening Mugshot should become part of the ritual: look around, use all senses, ground yourself, notice the environment, and explore the sip while it is happening.

**Agreed decision:** Optimize the flow for in-the-moment, one-handed mobile use at the table. Autosave, interruption recovery, low step count, and optional depth are essential.

## 3. What is the minimum public Mugshot that deserves to appear in the feed?

**Joe's answer:** The wording was unclear, so Joe skipped it and asked for a better question.

**Agreed decision:** Unresolved in this round. Round 3 and Round 7 later locked the per-context minimums. No additional quality threshold, prose length, or required criteria should be inferred here.

## 4. What should a Mugsy placeholder communicate when a post has no photo?

**Joe's answer:** It should be cute, inviting, and a little comedic: essentially "oops, forgot to take a picture." It serves someone who still wants to keep and post the memory.

**Agreed decision:** Make the placeholder clearly intentional and on-brand, without shaming the user. Final illustration and copy remain visual-design work.

## 5. If someone has both a caption and a shared raw take, how should they feel different?

**Joe's answer:** Keep the feed uniform with the caption. Everyone needs at least a caption. If the user makes the raw dump available, followers can click into the post to see it.

**Agreed decision:** Caption is the public-facing summary; raw note is secondary, expandable journal material.

## 6. What immediate moment after publishing should make the user want to do it again?

**Joe's answer:** Mugshot completion status, Mugsy cheering or dancing, immediate friend notifications, and resulting engagement. The fun is both having slowed down intentionally and seeing friends react.

**Agreed decision:** After a successful publish, celebrate briefly and land on the completed post. Social response is a separate activation milestone, not a reason to make publishing itself feel incomplete.

## 7. What social feedback belongs beyond likes and comments?

**Joe's answer:** Tasteful but strong notifications, likes, comments, and friend tagging. If people were together, they might join a post into a shared memory while retaining separate sip and cafe reactions.

**Agreed decision:** Shared memories are a meaningful future social primitive. In V3 alpha, invitation belongs on the publish screen; true grouped shared visits can follow once the core flow is proven.

## 8. If a combined public score is low, how should Mugshot prevent one unusual drink from damaging a cafe's reputation?

**Joe's answer:** It does not need to. Mugshot is not Yelp or Google Reviews. It is a personal journal with a social layer among friends. If someone did not like an experience, that is their experience.

**Agreed decision:** Do not distort or suppress personal scores to protect businesses. Frame scores as a person's memory and reaction, not an objective venue grade or aggregate public review claim.

## 9. How should Mugshot handle captions attacking an identifiable employee?

**Joe's answer:** Build a robust report feature. Tight automated language logic may flag content before posting, but it must not overreach; saying "Sarah was mean" is part of a user's experience and not automatically an attack. Lean on user reporting.

**Agreed decision:** Use narrow pre-publish intervention for high-confidence slurs, hate, threats, doxxing, or targeted abuse. Preserve ordinary criticism. Reporting, blocking, review, and enforcement are required. The exact policy for naming a non-public employee remained unresolved and needs a written safety policy before broad release.

## 10. What keeps the fifth log of the same weekly drink interesting?

**Joe's answer:** Tasteful badges, progress analogous to a Strava personal record, palate tuning, and Mugsy nudges that help the user notice something different or try an adjacent choice. Repetition provides useful personal data and supports local cafes.

**Agreed decision:** Reward learning, noticing, experimentation, and memory continuity, not consumption volume. Mugsy may vary prompts based on prior entries but cannot manufacture novelty or pressure purchases.

---

# Round 3 of 8: Frequency, minimums, sharing, and safeguards

## 1. In an ordinary week, how often does the core person visit a cafe, and how many visits should become published Mugshots?

**Joe's answer:** Roughly two cafe visits: perhaps one weekday visit for a work-from-home employee and one or two on the weekend. Mugshot must also work frequently for home makers, ranging from expensive espresso setups and homemade syrups to Nespresso, moka pot, V60, or simple experiments.

**Agreed decision:** The repeat-use model cannot depend on paid cafe visits. Cafe and Home are both first-class activation paths.

## 2. How long can Log a Sip take before it feels like work?

**Joe's answer:** The gut limit is three minutes, but steps matter more than elapsed time. Someone may intentionally spend 10-15 minutes reflecting, while a friend may want one line, a score, and done. Both must work.

**Agreed decision:** Maintain a sub-minute fast path after visual selection and an optional reflective path under three minutes for typical use. Longer time is acceptable only when voluntarily spent writing or exploring.

## 3. Is this the right minimum: visual, drink name, context, caption, sip score, and audience?

**Joe's answer:** Yes. Do not add or remove anything. That minimum captures the visual, drink, caption, sip score, context, and sharing choice.

**Agreed decision:** This is the global minimum. Context-specific requirements are refined below.

## 4. At a cafe, must someone complete cafe reflection before publishing?

**Joe's answer:** Try requiring both sip and cafe for someone who sits in the cafe. If it is to-go, they may publish only the sip and label it to-go. A minimal cafe star is enough when they do not want details.

**Agreed decision:** Seated Cafe requires a cafe score, not written reflection or criteria. To-go makes cafe reflection optional.

## 5. Does a photo, caption, and sip score count as complete without raw note, descriptors, or criteria?

**Joe's answer:** Yes. It is not the richest behavior, but many people will only want that. Mugshot must support both get-in/get-out posting and a 10-15-minute deep reflection.

**Agreed decision:** Raw notes, flavor descriptors, criteria, and weights are always optional. Do not visually shame a valid fast-path Mugshot as incomplete.

## 6. In a shared visit, should friends' scores be visible before someone submits their own?

**Joe's answer:** Prompt people to form independent first impressions, but provide an option to reveal the post they are joining because some people will want that flexibility.

**Agreed decision:** Default to concealed companion scores during reflection. Make reveal deliberate and reversible; do not hard-block it.

## 7. What location should friends see immediately when someone publishes from a cafe?

**Joe's answer:** The cafe location is fine and can create spontaneous connection. Never use other location data. At home, never expose the address; show Home or whatever safe label the user chooses.

**Agreed decision:** Public location is the selected place/context label, not live device coordinates. Home-address protection is non-negotiable.

## 8. What should a shared-visit feed card emphasize first?

**Joe's answer:** The group memory. Mugshot is about the social layer and creating memories together.

**Agreed decision:** Lead with shared time/place and participants, then let viewers inspect each person's drink and reactions.

## 9. Which friends should generate immediate Mugshot notifications?

**Joe's answer:** Initially, all friends, like the 18Birdies golf app. A notification such as "Kelly just posted" should prompt a quick, curious open. Test it; tone it down only if focus groups or usage show it is too much.

**Agreed decision:** Alpha defaults to notifying friends of each published Mugshot. Notification fatigue and mute behavior are explicit alpha hypotheses, not settled permanent policy.

## 10. Where should someone land after Mugsy celebrates publishing?

**Joe's answer:** On their completed post, so they can verify the pictures and information just as they would after publishing to another social platform.

**Agreed decision:** Celebration transitions directly into the canonical finished-post view.

## 11. Which behaviors deserve badges, and which should never be rewarded?

**Joe's answer:** Do not reward spending, overconsumption, or going out more just to maintain progress. Reward noticing new things, adding friends, trying new spots, exploring, education, and using Mugsy as a coach. The three pillars are exploration, education, and social connection.

**Agreed decision:** No purchase streaks, caffeine streaks, visit-frequency pressure, or spend-based status. Rewards must point to expression, learning, exploration, and connection.

## 12. May captions identify a non-public cafe employee by name, and where does criticism become attack?

**Joe's answer:** Joe did not claim expertise and asked the product to follow Apple and established platform standards, with review for slurs, hate, and personal attacks.

**Agreed decision:** The exact naming rule remains unresolved. Before public scale, define and enforce a moderation policy covering personal data, threats, harassment, hateful conduct, targeted abuse, appeals, and reports. Honest criticism of service remains allowed.

---

# Round 4 of 8: Cafe, Home, and Everywhere Else

## 1. How should Mugshot determine Cafe, Home, or another context?

**Joe's answer:** The user should choose at the start, likely through a clean pill or segmented control. "Other" is too weak because camping, airplanes, and many settings matter. Joe invited UX research on the exact control.

**Agreed decision:** Start setup with a visible three-way `Cafe / Home / Elsewhere` selector. It is an intentional click, not an inferred location decision.

## 2. What should be saved for a Home drink so it can be recreated six months later?

**Joe's answer:** Support optional depth appropriate to the drink. A homemade cherry syrup may have its own reusable recipe or source link. Coffee may include bean, origin, roast, roast date, dose in/out, time, pressure, flow, water, milk, and syrup amount. Matcha, tea, espresso pods, French press, moka pot, V60, Chemex, and other methods need relevant fields. The flow must also allow a casual person to save only the pod, milk, or flavoring and move on.

**Agreed decision:** Use progressive, method-aware structured fields. Recipe name, ingredients, amounts, source, equipment, method, and a small set of method-specific variables can be reusable; all advanced details remain optional.

## 3. What should an at-home Mugshot score represent without a cafe component?

**Joe's answer:** It may not need any additional context score. An optional "Would you make it again?" or mood/inspiration signal could help, but Joe wanted recommendations.

**Agreed decision:** The Home Mugshot score is the sip score. `Make it again?` is a separate intent, not another numerical rating and not part of the score formula.

## 4. Should making the drink receive a separate evaluation?

**Joe's answer:** No. Equipment, method, and recipe are supporting evidence for the sip score.

**Agreed decision:** Do not create a technique score or maker score in V3.

## 5. How should Mugshot show an evolving home experiment?

**Joe's answer:** Keep versions behind the scenes. Ask whether it is the same or a tweak; if changed, create the next version and make it easy to compare what was better or worse.

**Agreed decision:** A Home recipe has lineage and immutable attempt history. "Make again" starts from the prior setup; changes create a new version rather than rewriting the old memory.

## 6. Which Home details should be structured and which should stay free-form?

**Joe's answer:** Equipment should be structured and reusable, similar to Fitbod remembering the equipment at each gym. Joe should enter a machine, grinder, French press, moka pot, V60, Chemex, or other gear once and reuse it. Structured fields should adapt to the method: espresso can expose bean, roast date, dose, yield, time, pressure, and flow; matcha or tea can expose relevant temperature and preparation data. Casual flows must remain light. Thoughts and the sensory brain dump remain free-form.

**Agreed decision:** Structure information that enables recreation, comparison, filtering, or reuse. Keep emotional reaction, sensory sequence, context, and unexpected observations in the raw note.

## 7. When friends make drinks together at someone's home, what location should the shared card reveal?

**Joe's answer:** Treat this as an occasional case. If the host safely labels the place Home, a shared card can say, for example, "Jared's Home," based on the profile name. Never put a private home on a public map.

**Agreed decision:** Use a user-controlled display label only. Never derive, publish, or map a home address.

## 8. What makes a to-go cafe reflection meaningful?

**Joe's answer:** Order readiness, wait time, and the small parts of the pickup interaction can be enough.

**Agreed decision:** To-go cafe reflection is optional and should suggest only relevant criteria such as speed, order accuracy, service, presentation, and value.

## 9. How should three drinks from one cafe visit appear in the feed?

**Joe's answer:** It is still one Mugshot post. It can include multiple photos and go drink by drink. A smart collage would be exciting but is not important for the first version; selecting one cover is sufficient.

**Agreed decision:** One post, one caption, one audience, one cafe reflection, multiple sip cards and photos. Smart collage is later scope.

## 10. For a market, hotel, park, office, campsite, plane, or trip, when is place part of the review rather than just a setting?

**Joe's answer:** The setting is part of the whole experience and memory. Coffee at a beautiful campsite or during a work trip can lift the Mugshot. Mugsy should use context-aware prompts to help the user notice what the setting contributed.

**Agreed decision:** Elsewhere is a first-class experiential context. Its reflection and score are optional, but when supplied the setting score contributes to the blended Mugshot.

## 11. How should exploration rewards include Home experimentation without encouraging equipment or ingredient purchases?

**Joe's answer:** Joe did not have an answer and requested suggestions.

**Agreed decision:** The accepted direction is to reward learning behaviors: repeating with one variable changed, documenting a recipe, noticing a new quality, improving reproducibility, or sharing knowledge. Never reward equipment count, ingredient spend, or purchase frequency.

## 12. What should Mugshot remember from the previous entry, and what should start blank?

**Joe's answer:** The recorded source sentence is incomplete after: equipment is a good thing to remember and the most recent setup should be reusable for another espresso or latte. The next round explicitly approved the prior interpretation of what Mugshot remembers.

**Agreed decision:** Remember reusable equipment, saved recipes, method presets, recent beans/tea/matcha, prior criteria as suggestions, pinned criteria, and an optional "Use last setup." Start the raw note, caption, overall ratings, criterion ratings, visit-specific importance, audience confirmation, and context reflection as a new entry. This decision is retained because Joe explicitly approved the Round 4 read-back, although the complete spoken source wording is not present in the supplied transcript context.

---

# Round 5 of 8: Multi-drink memories, recipes, and taste learning

## 1. What should the prominent score communicate when one cafe Mugshot contains several drinks?

**Joe's answer:** Show that it is blended. Let the user tap an icon or score to see the individual drinks and cafe score. Blend the sips together, then blend that result with the cafe to get the Mugshot score.

**Agreed decision:** Make the hierarchy explicit: individual sip scores -> blended sip score -> cafe/setting score -> Mugshot score. Do not hide distinct reactions behind one unexplained number.

## 2. How should followers understand very different sip scores under one cafe experience?

**Joe's answer:** Clearly show the cafe once and list each sip separately. That is understandable and sufficient.

**Agreed decision:** Preserve individual sip names and scores in post details; context remains shared.

## 3. What does a setting score mean for a park, airplane, hotel, market, or campsite?

**Joe's answer:** The same thing as a cafe score: how the setting shaped the whole memory. A basic black coffee at a beautiful campsite may still produce a strong Mugshot score.

**Agreed decision:** Setting score is evaluative, personal, and blendable when present. It is not an objective rating of a public place.

## 4. When should Elsewhere require a setting reflection?

**Joe's answer:** It should always be optional, although the product should encourage reflection when it adds meaning.

**Agreed decision:** Elsewhere never blocks publishing because setting reflection is absent.

## 5. How should "Make it again" appear beside a Home sip score without becoming another rating?

**Joe's answer:** Follow strong UI practice and keep it clear that this means whether the drink is worth recreating, like "Would you return?" for a cafe. It should not participate in the criterion or rating math.

**Agreed decision:** Use a separate, plain-language intent control such as `Make again` / `Not this version`, visually outside the star-score equation.

## 6. When several recipe variables changed and the result improved, how certain should Mugsy be about cause?

**Joe's answer:** Be cautious. Summarize the changes and observed improvement without claiming which one caused it. Nudge the user to change one variable next time.

**Agreed decision:** Mugsy may describe correlation and propose a controlled next experiment. It must not present causal certainty unsupported by the user's history.

## 7. What should Mugsy suggest after an unsuccessful Home attempt?

**Joe's answer:** Keep it positive and lighthearted: "can't win them all; let's try differently." If the system has reliable domain knowledge, it can propose a relevant adjustment, such as grinding finer after an unintended 18-second espresso shot.

**Agreed decision:** Coaching must be opt-in, encouraging, specific, and framed as an experiment. Advice quality and safety need evaluation before broad automated coaching.

## 8. Which recipe details should followers see and what stays private?

**Joe's answer:** Let the author choose public or private. A creator can show that a private recipe was used without exposing ingredients or steps. A public recipe can reveal the full structured recipe. This supports people who sell recipes or keep them in an external cookbook.

**Agreed decision:** Recipe visibility is independent from post visibility, private by default, and explicit at publish time.

## 9. When a friend saves or adapts a recipe, how should credit be preserved?

**Joe's answer:** Use a very small credit callout with the creator's handle and an indicator that the recipe was used as a base or varied. Preserve inspiration without turning the post into an advertisement.

**Agreed decision:** Saved/adapted recipes retain immutable source attribution and a link to the known source version.

## 10. How can coffee, matcha, and tea creators offer reusable recipes without making Mugshot influencer-first?

**Joe's answer:** If a recipe appears naturally in Friends or Everyone and looks good, a viewer can save it into their Home Cafe. Mugshot does not need aggressive "try my recipe" calls to action.

**Agreed decision:** Discovery is post-led and optional. Avoid popularity pressure, promotional ranking, and growth mechanics centered on creator conversion.

## 11. How should Home and Cafe entries contribute to a personal taste profile?

**Joe's answer:** They should work together. The Taste Passport should use every relevant data point available from both.

**Agreed decision:** One personal taste model spans all contexts while retaining provenance so every insight can explain which sips, criteria, recipes, and places support it.

## 12. What should confirmation feel like when Mugshot extracts information from a bag photo, recipe link, or raw note?

**Joe's answer:** Fast and streamlined. Do not make the user confirm every field line by line and put the phone down before finishing the Mugshot.

**Agreed decision:** Present one compact, editable extraction summary. Require explicit acceptance before saving structured facts, highlight low-confidence items, and never publish extracted content automatically.

---

# Round 6 of 8: Recipe rights, privacy, and social boundaries

## 1. What is the default recipe visibility on the first Home Mugshot?

**Joe's answer:** Private. Sharing must be an intentional action.

**Agreed decision:** Recipe privacy defaults to Private for every new recipe until the user deliberately changes it. A previous public choice must not silently disclose a new recipe.

## 2. What should followers see when a recipe is private?

**Joe's answer:** Recipe name, creator, photo, and sip/post context. Use a small, on-brand Mugsy lock treatment to show that the underlying recipe is private.

**Agreed decision:** Followers may see the existence and identity of the recipe, but no protected ingredients, quantities, steps, equipment details the author marked private, or private source content.

## 3. What control does an author retain over saving or adapting a public recipe?

**Joe's answer:** If it is public, people can save and adapt it freely.

**Agreed decision:** Public means reusable inside Mugshot with attribution. The publish action must explain this consequence before the first public share.

## 4. What happens to a saved copy if the original becomes private or is deleted?

**Joe's answer:** The saved copy stays with the person who saved it. That consequence reinforces private-by-default publishing.

**Agreed decision:** Preserve the recipient's snapshot and attribution. Stop future access to the original and do not expose later private updates.

## 5. How should a long adaptation lineage appear without clutter?

**Joe's answer:** Perhaps show the latest adaptation and original credit, such as "latest adaptation: Jake" and "original: Ethan." The exact treatment needed workshopping.

**Agreed decision:** Keep the post surface compact with original creator plus immediate source. A detail view may expose the complete lineage. Exact copy and iconography remain unresolved visual work.

## 6. How should Mugshot distinguish original, externally linked, adapted, and purchased recipes?

**Joe's answer:** Use a small on-brand icon. Purchased recipes must not be redistributed publicly just because the user logged them.

**Agreed decision:** Record source type and rights metadata. Externally purchased/private-source recipes cannot become publicly viewable recipe instructions; a post may name or link the source without copying protected content.

## 7. Which recipe events should notify the creator?

**Joe's answer:** Provide robust notification settings. A creator can choose notifications when people make or adapt a recipe; otherwise, a quiet counter showing uses and adaptations may be enough.

**Agreed decision:** Recipe notifications are configurable and non-essential. Counts should be informational, not competitive.

## 8. Which public recipe signals are acceptable without creating influence pressure?

**Joe's answer:** Joe requested a recommendation rather than naming a specific set.

**Agreed decision:** Favor neutral utility signals such as `Made`, `Saved`, and `Adapted`, plus friends' relevant activity. Avoid leaderboards, viral rankings, purchase links as the primary action, and pressure language. Exact public counters remain an alpha/content-design hypothesis.

## 9. What should viewers see when participants in a shared visit choose different audiences?

**Joe's answer:** Do not force everyone to match because one person may want a private memory. Joe requested a workable viewer model.

**Agreed decision:** Audience remains participant-owned. A viewer sees only participants/posts they are authorized to see; the grouped card gracefully collapses hidden people rather than leaking their identity, score, caption, or participation. Exact empty-state language remains design work.

## 10. What happens when someone edits, deletes, or leaves a shared visit?

**Joe's answer:** Edits remain on that person's side. If someone deletes or leaves, the other memories become solo while retaining appropriate tags where still authorized.

**Agreed decision:** Each participant owns their contribution. Removing one contribution never deletes another person's journal memory. Shared presentation recomputes from the remaining authorized participants.

## 11. What does blocking do to old shared visits, recipes, tags, comments, and notifications?

**Joe's answer:** Remove shared visits, tags, comments, and notifications between the blocked users. Offer a prompt about whether to remove saved shared recipes.

**Agreed decision:** Blocking immediately severs mutual social surfaces and future notifications. Personal journal records remain private to their owners. Saved recipe-copy handling requires a clear user choice and must not leak blocked-user activity.

## 12. What determines which Mugshot appears first in each feed?

**Joe's answer:** `Your Mix` should use a robust blend of friends, recency, and relevance. `Everyone` is a way to see the broader community and should simply show the most recent posts.

**Agreed decision:** Friends/Your Mix may be relevance-ranked and must remain understandable. Everyone begins reverse-chronological; no popularity-first creator feed is part of V3.

---

# Round 7 of 8: Exact flow, drafts, and recovery

## 1. Does "two-screen flow" really mean two reflection surfaces plus a lightweight publish sheet?

**Joe's answer:** Yes as a gut direction, subject to app-pattern research if a better structure exists.

**Agreed decision:** Later clarification locked five screens total: setup, sip reflection, context reflection, publish review, and Taste Passport. Publish is a full screen, not a bottom sheet. The two reflection surfaces remain the conceptual center.

## 2. What should happen in the first ten seconds after choosing Cafe, Home, or Elsewhere?

**Joe's answer:** Land on a sip setup canvas with a large photo slot and drink-name field, not an immediately opened camera.

**Agreed decision:** The user retains control over camera, library, placeholder, and draft recovery. The drink name belongs on setup.

## 3. When should the "I missed the photo" Mugsy placeholder become available?

**Joe's answer:** Only after the user deliberately taps that option. Mugshot should strongly encourage real pictures but never hold the journal entry hostage.

**Agreed decision:** Do not auto-insert a placeholder and do not make it the equal-prominence first action. Make the escape visible when needed.

## 4. Are these context minimums correct?

**Joe's answer:** Yes:

- Seated Cafe: photo or placeholder, drink name, caption, sip score, cafe score, audience.
- To-go: photo or placeholder, drink name, caption, sip score, audience; cafe reflection optional.
- Home: photo or placeholder, drink name, caption, sip score, audience; recipe optional.
- Elsewhere: photo or placeholder, drink name, caption, sip score, audience; setting reflection optional.

**Agreed decision:** These are the alpha validation rules. Raw note, criteria, importance, flavor explorer, and coaching remain optional in all contexts.

## 5. May Mugsy turn a raw note into a caption suggestion when requested?

**Joe's answer:** No for V3. Avoid feature bloat and let people own the creative process. Reconsider only if research specifically asks for it.

**Agreed decision:** Caption begins blank and is human-written. No generative caption action in alpha.

## 6. When someone opens Mugsy coaching, should answers be inserted into the note or criteria?

**Joe's answer:** Start with thinking prompts only. The questions should help fingers or voice move while the person writes their own raw thoughts.

**Agreed decision:** Mugsy coaching is a lightweight, resumable prompt overlay with forward/back navigation. It does not write, score, or add criteria for the user.

## 7. If criteria suggest 2.3 but overall is 4, should the user see a voluntary action to adopt 2.3?

**Joe's answer:** Yes. Keep 4 and quietly show the suggested result with a `Use 2.3` action. Validate it in focus groups.

**Agreed decision:** Locked for alpha as an explicit hypothesis. Track whether this clarifies reflection or creates doubt.

## 8. Should importance use Less, Normal, More, and Most, and how should previous criteria return?

**Joe's answer:** Use human language. `Use last criteria` could slide out or appear as a simple option. Pinning a criterion so it returns every time is appealing. Keep the flow streamlined.

**Agreed decision:** Hide numeric multipliers in normal UI. Prior criteria return as suggestions with ratings and visit-specific importance blank. `Use last setup` is optional; pinned criteria persist as empty rows ready for the current visit.

## 9. What happens when someone leaves midway, including when several drafts exist?

**Joe's answer:** Autosave immediately, keep drafts as today, make them easy to delete, and return an opened draft to its latest state.

**Agreed decision:** Every meaningful edit persists locally without a manual save action. A draft list supports multiple unfinished Mugshots, clear identity, deletion, and resume from the last surface.

## 10. If publishing fails or the user is offline, should Mugshot queue and retry?

**Joe's answer:** Yes to both: retain a ready-to-post draft with one-tap retry and automatically push when connection returns.

**Agreed decision:** Queue publishing idempotently, make status visible, preserve user control, and prevent duplicate posts.

## 11. How do multiple drinks fit the flow?

**Joe's answer:** `Add another drink` creates another sip card on the same screen. Cafe is reflected once; the post has one caption and audience; final publishing covers the entire memory.

**Agreed decision:** Locked.

## 12. When do shared-visit invitations happen, and what edits preserve engagement?

**Joe's answer:** Invite on the publish screen. Each participant can edit the same kinds of fields they can edit on a normal Mugshot, but only on their side of the shared visit.

**Agreed decision:** Invitation does not interrupt reflection. Ordinary non-destructive edits preserve likes/comments on the canonical post. A precise edit-history and material-change policy was not fully answered and remains unresolved before shared visits ship.

---

# Round 8 of 8: Alpha shape, evidence, and go/no-go

## 1. Who participates in the first alpha?

**Joe's answer:** About 12 close friends and family, mostly casual cafe-goers with some Home users. A 20-30-person segmented panel is more appropriate for beta.

**Agreed decision:** Recruit for behavior coverage rather than statistical significance. Record which testers are casual, Home makers, and reflective coffee/tea/matcha users so results are not treated as one uniform cohort.

## 2. Must Cafe, Home, and Elsewhere all ship in alpha?

**Joe's answer:** Yes. Cafe and Home should be complete first-class contexts. Elsewhere can initially be a flexible setting name with optional reflection instead of advanced location intelligence.

**Agreed decision:** All three contexts are an alpha gate. Sophisticated Elsewhere inference is not.

## 3. Which advanced features belong in alpha?

**Joe's answer:** The core recommendation includes two reflection surfaces, publish review, photo and placeholder, raw note, caption, scores, custom criteria, human-language importance, use last setup, Mugsy prompts, flavor explorer, drafts, reliable publishing, audience, feed, and finished post. Joe also explicitly requested pinned criteria, full Taste Passport, and sophisticated machine learning in alpha V1. Smart collage, true grouped visits, public recipe lineage, and advanced adaptation can be alpha V2 or later.

**Agreed decision:** The creator's requested alpha scope is preserved. However, "sophisticated machine learning" is not yet a testable requirement and must be decomposed into specific user-visible behaviors before it can be an engineering gate. Deterministic suggestions or fixture-driven prototypes may validate the experience before a learned model exists. This is a scope-risk item, not permission to remove Taste Passport or personalization silently.

## 4. How should first-time use introduce Log a Sip?

**Joe's answer:** Mugsy should provide a short onboarding, connected to the full-app Mugsy onboarding already being developed.

**Agreed decision:** Keep Log a Sip onboarding brief and contextual. It must not recreate Guided mode as a mandatory tutorial.

## 5. What does activation mean?

**Joe's answer:** Publishing and friend interaction both matter. Joe accepted first publication as product activation and first friend interaction as social activation.

**Agreed decision:** Track them separately:

- Product activation: first successfully published Mugshot.
- Social activation: first meaningful friend interaction given or received.

## 6. What is the primary repeat-use signal?

**Joe's answer:** A second published Mugshot within seven days.

**Agreed decision:** This is the primary alpha retention event.

## 7. Are the proposed alpha targets acceptable?

**Joe's answer:** Yes for now, though Joe wants substantially more than 40% repeating within seven days.

**Agreed decision:** Initial targets:

- Median fast path: under 60 seconds after a visual is chosen.
- Median reflective path: under three minutes.
- At least 75% of testers who enter a drink name either publish successfully or intentionally save a draft.
- At least 40% of activated testers publish a second Mugshot within seven days.

The 40% target is a floor for learning, not the desired mature result.

## 8. What evidence should make Mugshot reconsider the blended score?

**Joe's answer:** Agree with a warning threshold where more than 25% of testers consistently call the blend misleading or repeatedly ask to publish sip and place without the blend.

**Agreed decision:** Keep the simple blend only if behavior and interviews support it. Reconsider at the stated threshold; also inspect repeated manual score overrides and avoidance of context scoring.

## 9. How should the alpha handle notifying friends about every Mugshot?

**Joe's answer:** Leave the all-friends notification behavior in the test. Add muting only if feedback shows people want it.

**Agreed decision:** Test broad notifications intentionally. The proposed 20% "disable all / repeatedly noisy" threshold is retained as a warning signal, but visible per-friend mute at initial alpha was not firmly approved and remains unresolved.

## 10. Is zero-loss recovery a non-negotiable alpha gate?

**Joe's answer:** Yes. Losing three to fifteen minutes of reflection would make people furious and damage trust.

**Agreed decision:** Force quit, screen loss, upload failure, offline use, reopen, retry, and multiple queued Mugshots must not lose or duplicate a memory.

## 11. What should Mugshot refuse to optimize?

**Joe's answer:** Refuse time spent, notification opens alone, paid visit count, drink purchase frequency, caffeine consumption, and streak preservation. Optimize for completed memories, repeat reflection, friend connection, and successful expression. Joe also asked how to build an analytics dashboard that makes these behaviors visible.

**Agreed decision:** Instrument events around the ethical outcomes below. Analytics vendor and dashboard implementation remain separate technical decisions.

## 12. What earns continued investment after alpha?

**Joe's answer:** All three: strong completion, repeat posting, and positive qualitative response. Enthusiasm without repeat use is not enough.

**Agreed decision:** V3 passes only when behavior and interviews agree.

---

# Consolidated alpha scope

## Alpha V1: required product surfaces

- Five-screen flow described above.
- Cafe, Home, and Elsewhere.
- One or more photos, cover selection, and deliberate Mugsy placeholder.
- Drink name and cafe/flexible setting selection.
- Optional private raw note.
- User-owned sip and cafe/setting scores.
- Suggested and custom criteria with star ratings.
- Human-language importance.
- `Use last setup` and pinned criteria.
- Mugsy thinking prompts.
- Interactive flavor explorer mapped to the approved flavor-wheel taxonomy.
- Required human-written caption.
- Audience and constrained raw-note visibility.
- Private-by-default recipe visibility.
- Draft autosave, offline queueing, retry, and idempotent publishing.
- Feed-ready finished post and post-publish celebration.
- Taste Passport with evidence and explanations.
- Alpha analytics for completion, recovery, repeat use, and social activation.

## Explicitly later unless separately pulled forward

- Smart multi-photo collage.
- True grouped shared-visit cards and full invitation lifecycle.
- Public recipe-lineage browser.
- Advanced recipe adaptation graph.
- Sophisticated Elsewhere location intelligence.
- Generative captions.
- Popularity-first creator mechanics.

## Machine-learning boundary for alpha

The phrase "sophisticated machine learning" does not override the interview's agency rules. Any alpha intelligence must be expressed as a bounded behavior such as:

- Rank likely criteria from the user's own prior choices.
- Suggest reusable equipment or a prior recipe.
- Extract possible structured fields into a compact confirmation summary.
- Generate cautious, evidence-linked Taste Passport observations.
- Offer domain-grounded next-experiment suggestions.
- Flag only high-confidence safety violations for review before publishing.

Each suggestion must expose provenance or reason where useful, remain editable, and require the user to publish or change their work.

# Measurement plan and decision gates

## North-star behavior

**Completed memories that lead to repeat reflection and genuine friend connection.**

This is not reducible to time spent, caffeine consumed, visits purchased, or notifications opened.

## Funnel events to instrument

1. Log a Sip opened.
2. Context selected.
3. Visual selected or placeholder deliberately chosen.
4. Drink named.
5. Sip surface entered.
6. Optional raw note started/completed.
7. Overall sip score selected.
8. Criteria suggested, selected, custom-created, rated, weighted, pinned, or removed.
9. Mugsy prompts opened/resumed/closed.
10. Flavor explorer opened and selections made.
11. Context surface entered/completed/skipped when allowed.
12. Publish review entered.
13. Caption completed.
14. Audience and raw-note visibility confirmed.
15. Publish attempted, succeeded, queued, failed, retried, or deduplicated.
16. Completed post viewed.
17. Friend interaction given/received.
18. Second Mugshot published within seven days.

Events should capture duration and path shape without recording private raw-note or caption content in analytics.

## Alpha success gates

- **Fast path:** median under 60 seconds after visual selection.
- **Reflective path:** median under three minutes for a typical reflective entry.
- **Completion/recovery:** at least 75% of people who name a drink publish or intentionally save a draft.
- **Repeat use:** at least 40% of activated testers publish again within seven days; higher is desired.
- **Qualitative fit:** testers describe the flow as fun, expressive, and worth repeating rather than survey-like.
- **Reliability:** no lost or duplicated memories in force-quit, offline, upload-failure, reopen, retry, or queued-post tests.
- **Context coverage:** Cafe, Home, and Elsewhere each produce understandable finished posts.

## Warning and stop conditions

- Reconsider the blended score if more than 25% consistently call it misleading or repeatedly request separate publishing without the blend.
- Reconsider all-friend notification defaults if roughly 20% disable all notifications or repeatedly describe the behavior as noisy.
- Rework the flow if criteria become a perceived requirement or cause casual users to abandon.
- Rework coaching if users believe Mugsy authored their thought, changed a score, or made a causal claim it cannot support.
- Do not continue investment based only on enthusiastic interview comments if completion and seven-day repeat behavior are weak.

# Privacy, safety, and ownership boundaries

## Journal and publishing

- Raw notes are private journal data by default.
- Captions are required and intentionally authored for the selected audience.
- Raw-note visibility is independently controlled and never broader than the Mugshot audience.
- Machine learning never publishes, changes an audience, reveals a recipe, or changes a score.
- Private content must not be placed in product analytics payloads.

## Location

- Publish selected cafe/place identity, not live precise coordinates.
- Home uses a safe user-selected label only.
- Never publish or place a private home address on the map.
- Shared Home memories may display a host label only to authorized viewers.

## Recipes

- Private by default.
- Public recipes are saveable and adaptable with attribution.
- A saved snapshot survives deletion or privatization of the original.
- Later private edits do not flow into old public snapshots.
- Purchased or protected external instructions cannot be republished as a public Mugshot recipe.
- Recipe existence, name, creator, photo, and sip may remain visible while instructions are locked.

## Social ownership

- Each participant owns their own contribution to a shared memory.
- Different audiences remain valid; viewers see only authorized contributions.
- One participant leaving or deleting does not delete another person's journal memory.
- Blocking severs shared presentation, tags, comments, and notifications while preserving each person's private journal data.

## Moderation

- Honest negative reactions and ordinary service criticism are permitted.
- High-confidence slurs, hateful conduct, threats, doxxing, and targeted harassment may be interrupted before posting.
- Reporting, blocking, review, enforcement, and appeals are required before broad public scale.
- The exact rule for naming a non-public cafe employee remains unresolved and must be written before beta/public release.

# Home and recipe model

## Home is first-class

Home is not "Cafe without a cafe." It has:

- Reusable equipment profiles.
- Method-aware optional fields.
- Reusable ingredients and recipes.
- Versioned attempts.
- `Make again` intent.
- Experiment comparison and cautious Mugsy coaching.
- Private-by-default recipe rights.
- Shared Taste Passport learning with Cafe and Elsewhere entries.

## Suggested structured field families

These are optional and appear only when relevant:

- **Identity:** recipe name, drink style, source creator/link, original/adapted/purchased/private-source status.
- **Coffee:** bean, producer/origin, process, roast, roast date.
- **Tea/matcha:** tea or cultivar/product, grade/type where meaningful, source, amount.
- **Equipment:** saved machine, grinder, brewer, kettle, whisk, scale, filter.
- **Espresso:** dose in, yield out, time, temperature, pressure/flow notes, grind setting.
- **Filter/immersion:** coffee and water amounts, ratio, grind, temperature, bloom, pours/steep, total time.
- **Matcha/tea:** leaf/powder amount, water amount, temperature, steep/whisk method and time.
- **Build:** milk, water, ice, syrups, ingredients, quantities, and assembly steps.
- **Lineage:** source version, current version, immediate adaptation source, original creator.

Raw sensory reaction and emotional context remain free-form.

# Taste Passport rules

- Combine Cafe, Home, and Elsewhere evidence.
- Use the user's own scores, criteria, importance, flavors, places, repeat choices, and recipe attempts.
- Describe patterns with evidence counts and confidence language.
- Distinguish early signals from consistent patterns.
- Provide `Why am I seeing this?`
- Avoid declaring a fixed identity from sparse data.
- Do not use the rejected bright/creamy/coffee-forward radar web.
- Do not turn the passport into a public expertise rank or consumption leaderboard.

# Open alpha hypotheses

The following were intentionally not treated as permanent truths:

1. **Equal blend clarity:** Does the simple sip + context average match how people understand the memory?
2. **Criteria advisory:** Does showing a weighted suggestion help reflection, or undermine confidence in the overall score?
3. **Importance math:** What coefficients, if any, best match Less/Normal/More/Most without producing surprising averages?
4. **Notification tolerance:** Are notifications for every friend's Mugshot delightful in a small network or quickly noisy?
5. **Photo placeholder:** Does a Mugsy placeholder preserve publishing without reducing photo-taking motivation?
6. **Seated requirement:** Does requiring a cafe score for a seated visit add meaning without causing abandonment?
7. **Taste Passport timing:** How much evidence is enough before an identity statement feels earned?
8. **Mugsy coaching:** Which prompts increase original reflection without feeling like a survey?
9. **Pinned criteria:** Do pins accelerate repeat use or make each visit feel pre-decided?
10. **Home depth:** Which method-aware fields create repeatability without turning Mugshot into brew-log work?
11. **Public employee naming:** What precise policy protects people without suppressing honest experience?
12. **Shared audiences:** Can viewer-specific grouped cards remain understandable without leaking hidden participation?
13. **Recipe social signals:** Which neutral counts are useful without creating influencer pressure?
14. **Machine learning scope:** Which user-visible intelligent behaviors create measurable value beyond deterministic recency and reuse?

# Provenance

This record was reconstructed from the complete eight-round product interview in the active Codex conversation on **July 20, 2026**, including Joe's later five-screen and visual-direction clarifications.

Supporting source artifacts:

- [Original synthetic logging-flow audit request](/Users/joe.rosso/.codex/attachments/e0443aa5-5127-4fe0-8579-d68d743aaedb/pasted-text.txt) — establishes the V1/V2 audit context that led to V3.
- [Three-direction visual feedback transcript](/Users/joe.rosso/.codex/attachments/51334bb8-3f3f-420c-95c5-6a03570e7214/pasted-text.txt) — preserves the visual comparison that led to the approved hybrid direction.
- [Synthetic logging-flow research archive](/Users/joe.rosso/Desktop/Projects/testMugshot/docs/audits/logging-flows-synthetic-research-2026-07-17/README.md) — repository evidence for the earlier Guided/Deep audit.

The two supplied attachment files do **not** contain a verbatim standalone transcript of all eight interview rounds. This document therefore preserves the substantive Q&A available in the conversation and explicitly labels the one incomplete source answer (Round 4, Question 12) and all unresolved policy/product items. It does not invent a final answer where Joe deferred the choice.

## Change-control note

Future design or implementation work may test these decisions, but it should not silently overwrite them. If alpha evidence changes a locked choice, update this file with:

1. the date,
2. the evidence,
3. the decision that changed,
4. the new rule, and
5. the person who approved it.
