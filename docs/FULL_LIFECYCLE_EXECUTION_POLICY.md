# Full-Lifecycle Roadmap Execution Policy

Applies to Phases 0–6 on `codex/full-lifecycle-roadmap`. Phase 7 remains deferred.

## Phase transitions

Exit gates are risk checklists and recommendations, not absolute completion locks. Advance when:

- The phase's primary user journey works end to end.
- Privacy, authentication, ownership, migration safety, and private-note isolation have no known high-severity defect.
- Automated coverage is proportionate to the change and the current build is healthy.
- Remaining gaps are low-severity, rare, tooling-specific, or release-polish items with a written follow-up.
- Advancing does not hide a data-loss, security, publishing, payment, or destructive-action risk.

Do not hold the roadmap for exhaustive device matrices, automation transport outliers, nondeterministic 0.1% edge cases, or redundant manual checks when the same invariant already has strong evidence.

## Judgment record

Each phase checkpoint records:

- What shipped and what was verified.
- Any unresolved risk and why it is acceptable to carry.
- Migrations, feature-flag state, and rollback path.
- The decision to advance.

Checkpoint commits remain local until the user explicitly approves a push. The final pull request and merge to `main` still require explicit approval.
