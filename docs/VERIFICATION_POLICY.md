---
document_type: living
status: current
last_verified: 2026-11-24
---

# Mugshot verification workflow

Use ECC testing, SwiftUI, security-review, and verification practices with checks
chosen for the actual change. Numbered verification tiers are retired. A label or
an elapsed-time target never substitutes for evidence that the requested behavior
works. The commands and runtime checklist are in
[IOS_QA_EFFICIENCY_FRAMEWORK.md](IOS_QA_EFFICIENCY_FRAMEWORK.md).

Brand changes also follow the [brand authority](brand/README.md). The fast
repository check runs `python3 scripts/brand-kit.py --check` to verify native
source/export equality, exact assets and copy, approved contrast pairs, local
links, and the absence of independent colors or remote UI resources. It also
runs `python3 scripts/mugsy-catalog.py --check` for the immutable master, seven
core shapes, pose mappings, reviewed PNGs, alpha registration, and native preview
freshness. New character generation requires optical review alongside these
deterministic checks; hashes cannot establish likeness. A brand
documentation/static-artifact change requires those checks and relevant visual
review, not an app build. A downstream app or website implementation still needs
the verification appropriate to its actual behavior and risk.

## Repository operations

- Keep the shared everyday checkout on current `main`. Start independent work
  from current `origin/main` in a managed worktree; continue an existing draft
  only from its recorded branch and dependency.
- GitHub protects `main`, including administrators: use a pull request, pass the
  required `Static checks` job against an up-to-date base, and resolve review
  conversations. Force pushes and branch deletion are disabled. A one-owner
  repository does not require an impossible second-person approval.
- Product acceptance holds remain binding even when GitHub reports a clean merge.
  Keep unfinished dependencies and approval-only prototypes draft and unmerged.
- Before removing branches or worktrees, record exact refs and preserve unique
  commits and working files in a verified recovery copy. A squash merge can
  integrate a change without making the original head an ancestor of `main`.
- Use the managed worktree archive workflow for managed checkouts. Preserve
  shared or active worktrees and their chat ownership.
- Repository metadata/documentation changes require scoped diff, documentation
  and static verification; they do not require an app build or runtime session.

## Before implementation

- Read repository instructions, affected code, call sites, and existing tests.
- Describe the behavior and regression risk: local presentation, domain logic,
  persistence, networking, authentication/ownership, media, lifecycle, or release.
- Classify living-document impact under [DOCUMENTATION_POLICY.md](DOCUMENTATION_POLICY.md).
- Reproduce each confirmed bug with a focused test or recorded runtime evidence.
  Use ECC's RED -> minimal fix -> GREEN loop. A compile-time RED is valid only
  when a test intentionally exercises missing behavior; broken tooling is not RED.
- Preserve relevant evidence and unrelated user changes. Record hypotheses as
  hypotheses until corroborated.

## Choose the checks that establish correctness

| Change | Required evidence |
| --- | --- |
| Documentation only | Scoped diff, formatting, documentation check; no app build |
| Copy or isolated visual polish | Scoped diff, repository static checks, one Debug compile for changed Swift/resources |
| Validation or local behavior | Focused regression and boundary tests plus compile/static checks |
| Persistence, network, auth, uploads, cancellation, or recovery | Success, failure, retry, ownership, stale-state and duplicate tests; relevant hermetic contracts; affected Simulator journey |
| Backend contracts or security | Disposable backend behavior/RLS tests, ownership/denial tests, caller review and relevant runtime integration |
| Signing, packaging, hardware-only behavior, or distribution | Relevant build/signature checks and explicitly authorized device/release gates |

A small copy or spacing change does not require a full journey. A publishing bug
cannot be declared fixed from compilation alone. User-requested verification takes
precedence. Explain materially longer checks before starting them.

## ECC testing and review

1. Add or extend tests that exercise the confirmed failure and meaningful boundaries.
2. Execute RED, implement the smallest coherent fix, then rerun to GREEN. Keep
   checkpoint commits and a concise evidence report when using ECC TDD.
3. Use injected dependencies, safe fixtures, and deterministic interruption points.
   Prefer pure tests and hermetic backend tests for logic; use Simulator when iOS
   behavior, SwiftUI interaction, lifecycle, or hosted tests require it. Focused
   Simulator TDD is permitted; consolidate broader acceptance after the fix.
4. Review SwiftUI state ownership, task lifetime, main-actor updates, loading/error
   feedback, accessibility, and existing architecture/design conventions.
5. Review auth/session boundaries, account ownership, input/media validation,
   sensitive logging, cleanup, and server-side authorization. Do not weaken a
   server guard to make a client test pass.
6. Run the applicable repository checks. `scripts/verify-no-simulator.sh fast`,
   `backend`, and `full-static` remain command modes, not verification tiers.
   `full-static` compiles app/test bundles without booting Simulator.
7. Inspect the complete diff and all changed contract consumers. Run
   `./scripts/check-documentation.sh` and `git diff --check` before completion.
8. Report coverage when collected. ECC's 80% target applies to newly exercised
   behavior where measurable; never imply an app-wide percentage from a focused
   suite or add meaningless tests to satisfy a number.

Reuse passing evidence. Rerun equivalent checks only after relevant changes,
failures, or a concrete unresolved uncertainty. Debug and Release are not both
routine; Release is for release/packaging or compiler-optimization risk.

## Data and release boundaries

- The linked Supabase project contains preserved user data. Remote diagnosis is
  read-only unless the user explicitly authorizes a narrowly scoped mutation
  against named disposable records.
- Never reset, seed, migrate, deploy, delete, or run mutating SQL tests against
  that linked project as routine verification. Use disposable local fixtures.
- Disable production analytics and verify backend targeting for runtime fixtures.
- Physical-device acceptance is owner-promoted. Finish safe local/Simulator work
  independently and report the hardware boundary without claiming acceptance.
- TestFlight remains an explicit manual gate after local validation. Follow
  [TESTFLIGHT_UPLOAD_HANDOFF.md](TESTFLIGHT_UPLOAD_HANDOFF.md); never archive,
  export, upload, assign builds, or bump marketing versions without authorization.

## Delivery and evidence

Use feature branch -> reviewed PR -> permitted merge, respecting repository
protections and unresolved dependencies. Report exact checks and results,
confirmed root causes/triggers, implemented fixes, and remaining blockers.
Separate implemented, locally verified, Simulator verified, physically accepted,
production configured/verified, and TestFlight accepted states. An eventual
recovery does not establish that the original publication experience succeeded.
Historical reports that mention tiers retain their original evidence and dates;
this document defines the current workflow.
