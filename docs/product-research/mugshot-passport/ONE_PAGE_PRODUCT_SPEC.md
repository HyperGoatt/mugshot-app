# Mugshot Passport — One-Page Product Specification

**Status:** Vision direction · **Selected visual direction:** Living Atlas · **Product principle:** one evolving Passport, never a second taste profile

## Product promise

Mugshot Passport turns a person’s sips, cafe visits, recipes, words, ratings, context, and memories into a living portrait of how they enjoy coffee. It should help someone recognize themselves, understand what changed, and decide what to try next—without reducing taste to a score, badge collection, or permanent label.

**Primary job:** “Show me what my coffee life says about me, prove it from my own memories, and let me correct it.”

## Canonical experience

There is one Passport object with permissioned views:

- **Owner Passport:** the complete, editable portrait in **Journal → Passport**.
- **Shared Passport:** a deliberately previewed, privacy-safe projection of the same object from Profile or a share link.
- **Passport update:** a compact post-publish receipt that links back to the canonical Passport; it is not another Passport.

The cover must answer three questions in under ten seconds:

1. **You reach for** — recurring choices, such as bright fruit-forward drinks.
2. **You notice** — the sensory qualities the person consistently mentions, such as body and clarity.
3. **You return to** — repeated rituals, places, recipes, and contexts.

A plain-language signature connects the lenses, for example: **“Bright, textural, and quietly ritual-driven.”** Each statement uses human confidence language—**New clue, Taking shape, Well established, Changing**—rather than percentages.

## Experience behavior

**First formation:** Before enough evidence exists, the Passport shows what it is learning, the memories that would strengthen it, and one inviting next step. It never presents fake certainty.

**After every publish:** The user sees one of five update states: **No change, Strengthened, New clue, Nuanced,** or **Fading**. The receipt names the affected pattern, shows the supporting entry, and offers **View in Passport**.

**Pattern stories:** Tapping a lens opens narrative pattern cards, not charts. Every card includes:

- the observation in ordinary language;
- the evidence families behind it;
- two or three tappable memories;
- where or when the pattern tends to appear;
- its current confidence word;
- **Why am I seeing this?** and **This does not fit me**.

Corrections should immediately hide or soften a pattern and improve future interpretation. The Passport may suggest a drink, cafe, recipe adjustment, or reflection only when the supporting reason is visible.

## Evidence and trust model

The Passport may learn from six evidence families: **choices** (drinks, beans, methods), **sensory language** (aroma, acidity, body, finish), **affect** (overall enjoyment), **ritual and context** (time, people, occasion, setting), **craft** (recipes and experiments), and **memory** (photos, notes, places, returns).

Popularity, likes, follower behavior, and friend ratings never change personal taste conclusions. Private notes remain owner-only by default. Location and social context are summarized at the least revealing level. The first time a shared Passport forms, the user must see an explicit preview and choose the audience. Every shared statement must be safe without exposing its private evidence.

## Information architecture and visual direction

The owner Passport is a first-class Journal destination, beside Memories. The profile shows only its compact shared cover. The interface uses the approved Mugshot language: warm cream canvas, foam surfaces, espresso text, sage and mint accents, editorial serif headlines, readable system sans body text, real photography, and restrained route or stamp details.

The selected **Living Atlas** direction makes memories and places the organizing visual. A privacy-safe, geographically nonliteral route connects photographic evidence to the pattern it supports. The broader visual metaphor remains a **well-kept field passport**: personal, accumulated, and alive. Photos and narrative evidence lead; ornament supports. Avoid radar or spider charts, progress rings, rankings, streaks, trophy badges, heavy gradients, nested cards, and dense dashboards. Body copy must remain readable at 13–15 pt minimum, color must not carry meaning alone, and Reduce Motion must preserve every state change.

## Alpha scope

**Must ship:** canonical cover; three lenses; plain-language signature; formation state; confidence words; pattern stories with evidence; post-publish updates; correction controls; owner/shared projections; first-share preview; audience controls.

**Later:** proactive recommendations, friend compatibility, recipe coaching, annual stories, and richer longitudinal comparisons.

**Non-goals:** consumption gamification, expertise scoring, a universal coffee palate ranking, medical or identity inference, and a second “Taste Passport.”

## Success definition

The feature succeeds when a user can accurately explain their Passport after one glance, open evidence when curious, correct a wrong conclusion without friction, and feel that the portrait becomes more personally useful over time. The north-star signal is **meaningful Passport return**: the share of active journalers who revisit a pattern, evidence memory, correction, or next-step suggestion within 30 days—not raw Passport opens.
