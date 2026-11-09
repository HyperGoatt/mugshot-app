---
document_type: historical
status: installed-physical-composer-verified
---

# Home recipe composer — physical acceptance, November 5, 2026

Current behavior: [Home recipes](../HOME_RECIPES_IMPLEMENTATION.md).
[Interview sources and implementation history](../design/home-recipe-composer-2026-11-04/README.md).
[Inspected fictional hardware captures](../design/home-recipe-composer-2026-11-04/gallery.html#phone).

## Candidate and scope

**Mugshot Luna QA 0.5.3 (8)** is installed and exercised on iPhone 16 Pro /
iOS 27.0.1 as the development app `co.mugshot.app.dev`. The candidate is source
commit `44967197b81f1d2d9c5fc10ab67d46ee9d76dacc`, with debug-library SHA-256
`9cc76f80d52401cf59254360cbc2abd39cf28f945d1dc09525549293cced1ae2`.
Deep/strict signatures, unchanged owner entitlements, actual-key exclusion and
disabled analytics retain their passing package receipts. The existing sandbox
APNs entitlement is unchanged; notification delivery is not exercised here.

This follow-up changes development installation/verification documentation only.
No product code, model, quota, hosted data, backend contract or deployment changes.
The prior unavailable trusted-device connection resolves over Wi-Fi after the
phone joins the Mac's network. No trust reset or network/security setting is
changed by the agent.

## Executed hardware checks

| Run | Result | Evidence |
| --- | --- | --- |
| Composition-domain suite | 17 pass; UI runner initialization then times out | `/tmp/mugshot-composer-physical-2026-11-05.xcresult` |
| Focused UI runner retry / capture screen | 1 pass, zero failures/skips | `/tmp/mugshot-composer-physical-runner-retry-2026-11-05.xcresult` |
| Remaining composer and Home-library journeys | 9 pass, zero failures/skips | `/tmp/mugshot-composer-physical-ui-2026-11-05.xcresult` |
| Explicit owner read-only component journey | 1 pass, zero failures/skips | `/tmp/mugshot-composer-owner-readonly-2026-11-05.xcresult` |

The first overall run is **failed** because UI automation does not initialize.
Its 17 passing domain cases are reused; retrying the short UI case succeeds with
the same candidate/toolchain. The exact timeout cause is not established, and no
app fix is inferred from recovery. Across the subsequent runs, all **27 selected
fixture cases** pass, plus the separate owner check. Existing passing Simulator
and static evidence remains in the implementation ledger; it is not rerun for
this documentation-only follow-up.

The UI cases exercise source-first capture, a reusable syrup combined with a
base/milk, component inspection and return, saved-part selection, quantity entry,
largest accessibility text with `125 ml`, method-correct matcha guidance,
standalone beans/gear, discovery, quick logging, and caption → guidance → selected
rating → shared private review. The complete composed-drink journey reaches the
same review screen. Mutable journeys run only in `co.mugshot.app.homeqa`, with
an invalid fixture backend, blank analytics token, isolated keychain and no owner
app groups, URL schemes or app extensions.

The owner check opens the existing blueberry component from Saved → Home library,
verifies guidance is available before starting a sip, opens **Use in a drink**,
finds the linked component and disabled Save for an unnamed mix, then closes
without typing or saving. No reset/UI-fixture flags are sent to the owner app.

## Data preservation and cleanup

- Fresh private backups preserve Application Support and Library/Preferences;
  the Documents inventory is empty. OS-protected SplashBoard snapshots are not
  included in the complete data comparison. Backups and owner captures stay
  outside the repository.
- All **43 original Application Support files** remain byte-identical after the
  fixture run and again after installation, before owner launch.
- After the owner check, the **entire recipe workspace remains byte-identical**:
  eight recipes, six attempts, fifteen sessions, one recipe draft and thirteen
  attempt drafts, including all saved source/version history and references.
- All shelf content remains identical except its normal `updatedAt` field.
  Two files in `MugshotBatteryDiagnostics` rotate during launch; no user record
  is inferred lost from that diagnostic housekeeping. The other forty original
  files remain byte-identical. Existing privacy/assistance preferences are unchanged.
- Remove the disposable flow app and both task test runners. Final installed-app
  inventory retains Mugshot and Mugshot Luna QA and excludes those temporary apps.
  The unrelated Mugshot Motion QA app is preserved.

[Sanitized machine-readable receipt](../design/home-recipe-composer-2026-11-04/phone-verification-2026-11-05.json)
records package identity, individual run outcomes, preservation and cleanup.
Only fictional fixture screenshots are published.

## Owner QA on the installed app

1. Open **Mugshot Luna QA → Saved → Home library → Recipes**. Open the existing
   blueberry syrup and choose **Use in a drink**.
2. Name a latte, choose a base and milk, and optionally enter the syrup amount
   used in this drink. Open the syrup's recipe and return to the same mix.
3. Save the drink recipe. Confirm the syrup's original batch and steps stay intact.
4. Choose **Make with guidance**, then continue through capture, rate and review.
   Check that the recipe/amounts make sense and the review is private by default.
5. Separately try **Add a recipe** with another real social source or screenshot,
   and manage a bag or gear without starting a sip.

Real source-extraction fidelity, the actual Photos/video/speech permission flows,
VoiceOver speech and a wider appearance/device matrix remain human QA. This run
does not guarantee access to every social caption/video or broad AI usefulness.
AI and inventory setup remain optional. The draft parent stack and TestFlight
gate are unchanged: no merge, archive, export, upload or build assignment occurs.
