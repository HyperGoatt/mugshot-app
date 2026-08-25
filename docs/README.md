---
document_type: living
status: current
last_verified: 2026-08-24
---

# Mugshot documentation

This index defines which documents describe Mugshot as it exists now. Source
code, forward Supabase migrations, and signed-build evidence remain the final
implementation evidence; living documents explain that evidence and must change
with it.

## Living sources

| Document | Authority |
| --- | --- |
| [Current product status](CURRENT_PRODUCT_STATUS.md) | Shipped behavior, validation state, and release gates |
| [Feature status matrix](FEATURE_STATUS_MATRIX.md) | Feature-by-feature implementation and risk status |
| [Real data flow status](REAL_DATA_FLOW_STATUS.md) | Remote authority, local fallback, and ownership boundaries |
| [Repository map](REPO_MAP.md) | App, target, service, test, and backend architecture |
| [Product roadmap](PRODUCT_ROADMAP.md) | Current sequencing and deferred product work |
| [Notification system](NOTIFICATION_SYSTEM.md) | Activity, APNs, device lifecycle, privacy, operations, and acceptance |
| [Current sprint](CURRENT_SPRINT.md) | Active notification work and TestFlight feedback ledger |
| [TestFlight feedback ledger](TESTFLIGHT_FEEDBACK_LEDGER.md) | Organizer-backed disposition and acceptance state for all 44 reports |
| [Post reaction contract](POST_REACTION_CONTRACT.md) | Expressive post-reaction ownership, compatibility, Activity, and verification contract |
| [Mugsy asset status](MUGSY_ASSET_STATUS.md) | Production artwork authority and review-only vector handoff state |
| [Supabase release workflow](SUPABASE_RELEASE_WORKFLOW.md) | Backend release, QA, safety, and drift policy |
| [Verification policy](VERIFICATION_POLICY.md) | Risk-tiered validation requirements |
| [PostHog analytics plan](POSTHOG_ANALYTICS_PLAN.md) | Privacy-safe event and measurement contract |
| [TestFlight upload handoff](TESTFLIGHT_UPLOAD_HANDOFF.md) | Manual distribution gate and tester copy format |
| [Documentation policy](DOCUMENTATION_POLICY.md) | Freshness, classification, and change requirements |
| [Changelog](CHANGELOG.md) | Concise behavioral and documentation history |

## Decision records

[Mugshot V3 Product Interview](MUGSHOT_V3_PRODUCT_INTERVIEW.md) is the locked
product-direction record. A decision record describes intent, not current
implementation status. Amend it explicitly when product policy changes; use the
living sources above for delivery state.

## Historical evidence

Dated audits, checkpoints, sprint reports, research, design evidence, release
notes, and deployment gates preserve what was true at the recorded time. They
are not implementation instructions unless a living document links to them as
current evidence. A historical document with an obsolete implementation claim
must carry a supersession notice rather than silently rewriting its chronology.

The following paths are historical by default:

- `docs/audits/`
- `docs/design/`
- `docs/product-research/`
- top-level files named `*_AUDIT.md`, `*_CHECKPOINT.md`, `*_SPRINT_*.md`, or
  `*_DEPLOYMENT_GATE.md`

## Update rule

Every change to product behavior, data authority, backend contracts, build or
distribution configuration, privacy, or release state updates
[the changelog](CHANGELOG.md) and every affected living source in the same
change. Run `./scripts/check-documentation.sh` before declaring the work done.
