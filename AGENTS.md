# Mugshot Repository Rules

- In every user-facing string and product document, use the ASCII spellings `cafe` and `cafes`.
- Never use an accented e in those words.

## Brand Authority

- Use [the Mugshot brand kit](docs/brand/README.md) as the single source of truth
  for all app, marketing, web, email, and social brand work.
- Reuse the kit's exact app-derived assets, generated tokens, and voice rules.
  Do not introduce a second palette, new font family, or redrawn identity asset.
- Update the kit and affected consumers together when identity changes, and run
  `python3 scripts/brand-kit.py --check` for brand changes.
- Mugsy changes also follow [the immutable identity contract](docs/brand/identity/README.md)
  and pass `python3 scripts/mugsy-catalog.py --check`. Poses and accessories may
  vary; the identity master and protected native shapes stay fixed.

## Repository Organization

- Before a new independent task, run `python3 scripts/prepare-task.py --repository app`. It refreshes the primary checkout and prints the verified starting commit. Create the feature worktree from that exact commit; refreshing main does not update an older feature worktree.
- Website, landing-page, SEO/GEO, public web-route and product-email work belongs to the sibling `mugshot-marketing` repository (`HyperGoatt/mugshot-marketing`). For that work, run `python3 scripts/prepare-task.py --repository both`, then use the printed marketing path and commit. Read its README and affected operating guidance before editing.
- Startup refuses a wrong origin, dirty primary checkout, unpublished/divergent main, or failed fetch. Resolve the ownership/source issue while preserving the existing work; never reset, stash, or overwrite it merely to make startup pass.
- Keep the everyday checkout on current `main`; use managed feature worktrees for independent work.
- Continue a held draft stack only from its recorded branch and dependency. Mechanical mergeability does not remove acceptance holds.
- Main requires a pull request, passing `Static checks` on an up-to-date base, and resolved review conversations, including for administrators. Never bypass these protections.
- Preserve exact refs, unique commits, and working files in a verified recovery copy before cleaning branches or worktrees. Account for squash merges.
- Archive managed worktrees with the supported app tool; preserve active or shared chat workspaces.

## Documentation Freshness

- Follow [`docs/DOCUMENTATION_POLICY.md`](docs/DOCUMENTATION_POLICY.md) for every change.
- Before implementation, classify whether the change affects product behavior, architecture/data ownership, Supabase contracts, build/distribution, privacy/safety/analytics, or no living documentation.
- Update [`docs/CHANGELOG.md`](docs/CHANGELOG.md) and every affected living document in the same change. Do not leave documentation cleanup for a later task.
- Distinguish implemented, locally verified, production-configured, physically accepted, and TestFlight-accepted states. Never claim a stronger state than the evidence proves.
- Preserve dated audits, checkpoints, and research as historical evidence. Add a supersession banner and current link instead of rewriting their chronology.
- Run `./scripts/check-documentation.sh` before declaring any repository change complete.

## Verification Policy

- Follow [`docs/VERIFICATION_POLICY.md`](docs/VERIFICATION_POLICY.md) for every change. Numbered tiers are retired; select evidence from the actual behavior and regression risk.
- Use ECC RED -> fix -> GREEN for confirmed behavior bugs, focused boundary tests, SwiftUI state/task review, security review, and a final verification report.
- Small local UI polish requires diff/static review and one compile check. Do not expand it into full runtime or Release testing without a concrete risk.
- Publishing, uploads, authentication, persistence, lifecycle, concurrency, and recovery require focused failure/retry/ownership/idempotency tests plus relevant runtime acceptance. Focused Simulator TDD is permitted when needed.
- Use safe local fixtures and disposable backend contracts. The linked Supabase project is read-only for routine diagnosis and verification.
- Reuse passing evidence; repeat or broaden checks only for changes, failures, or unresolved uncertainty. Explain materially longer checks before starting them.
- Documentation-only changes require diff/format/documentation checks and no app build. Run `./scripts/check-documentation.sh` before completion.
- Distinguish local, Simulator, physical-device, production, and TestFlight evidence. Physical-device testing is owner-promoted; TestFlight remains a separate explicit gate.

## TestFlight Upload Handoff

- TestFlight is a manual release gate. Never archive, export, upload, or assign a build unless the user explicitly asks after local validation is complete.
- Before any TestFlight handoff, build and run the candidate on a local Simulator and on the user's connected iPhone. Report either gate as blocked instead of bypassing it.
- Keep prerelease candidates on the currently approved App Store marketing version unless the user explicitly approves a version bump. Increment build numbers because App Store Connect does not permit reusing a version/build pair.
- Every TestFlight archive, upload, or testing-group handoff must include a ready-to-paste **What to Test** blurb in the final response.
- Tailor the blurb to the exact version/build and its meaningful product changes. Lead with the primary new behavior, then name the most important regression paths and failure states.
- Keep the copy tester-facing, concise, and suitable for App Store Connect's 4,000-character field. Do not include implementation jargon, secrets, private identifiers, fabricated claims, or features that are not present in the uploaded build.
- Include explicit privacy or access-control expectations whenever the build changes sharing, authentication, user content, permissions, or public links.
- If the build has already been uploaded, report its processing status and current testing-group state alongside the blurb so the user can assign it without reconstructing release context.
- Use [`docs/TESTFLIGHT_UPLOAD_HANDOFF.md`](docs/TESTFLIGHT_UPLOAD_HANDOFF.md) as the reusable format.
