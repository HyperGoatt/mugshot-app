---
document_type: historical
status: installed-and-launch-verified
date: 2026-11-13
---

# Premium polish — build 18 iPhone installation

Current delivery status: [product status](../../CURRENT_PRODUCT_STATUS.md).
This receipt supersedes the earlier [connection blocker](PHONE_DELIVERY.md).
The owner explicitly requested installation and launch with existing data
preserved, without TestFlight. Documentation impact is development delivery
evidence only; product code and backend contracts are unchanged.

## Delivered

**Mugshot Luna QA 0.5.3 (18)**, `co.mugshot.app.dev`, replaced **Mugshot QA
0.5.3 (16)** in place on the owner's iPhone 16 Pro / iOS 27.0.1. The installed
app inventory confirms build 18. Normal foreground launch succeeded without
fixture/reset arguments. The app opened on Feed, and its process remained
running at the follow-up check.

Product source is `a52be2f4cbdb144d13cc846c908eab41513522f5`. The already-verified
iOS 27 development package was reused; its deep signature and executable hash
were checked again before installation. Main app and both extension entitlements
match the retained build 16 package, preserving the development bundle, keychain
identity, app group, and backend configuration. Analytics remains disabled.
[Package verification and hash](PHONE_DELIVERY.md#prepared-candidate).

## Data preservation

The app was not running before backup. Private copies captured **57 app files**
and **one shared-container preferences file**. Documents was confirmed empty.
No uninstall, data reset, sign-out, fixture seeding, or content deletion occurred.

Before launch, all content and preferences matched the backup byte for byte.
iOS replaced two SplashBoard launch snapshots and assigned a new app data
container path; the shared-container path stayed the same.

After launch:

- All **45 Application Support content files** still matched their original
  SHA-256 hashes.
- App preferences retained every key and value. The only semantic comparison
  adjustment was the ordering of the same 40 personal-library cafe IDs.
- Shared preferences retained every key and value; the eligible-list JSON was
  re-encoded with unchanged decoded content.
- Loader/network caches and iOS launch snapshots changed as runtime artifacts.
  No stored content was missing.

Raw before/after backups, manifests, comparison results, installation/launch
receipts, and the consolidated preservation summary remain private under
`.codex/premium-polish-iphone-2026-11-13/`, excluded from Git. The foreground
screen was inspected; no owner-content screenshots are published with this receipt.

## Acceptance boundary

This establishes physical development installation, data preservation, and
normal launch. It does not establish hands-on acceptance of every changed flow,
resolve the parent dependency holds, or establish TestFlight acceptance.
The existing [Simulator audit and coverage](README.md) remain separate evidence.
No backend deployment, archive, export, upload, or TestFlight action occurred.

The follow-up documentation passed `./scripts/check-documentation.sh` and
`git diff --check`. No product source changed, so no additional app build or
regression suite was required.
