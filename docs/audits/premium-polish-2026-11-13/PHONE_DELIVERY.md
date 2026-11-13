---
document_type: historical
status: prepared-device-unavailable
date: 2026-11-13
---

# Premium polish — iPhone development delivery

**Superseded delivery status:** the connection was restored and build 18 was
[installed and launched with data preservation verified](PHONE_INSTALLED.md).
The preparation and initial blocker below are retained as historical evidence.

Current delivery status: [product status](../../CURRENT_PRODUCT_STATUS.md).
The owner requested an in-place iPhone installation with existing data preserved
and no TestFlight upload. This follow-up affects signing/build delivery evidence
only; it does not change product code, backend configuration, or marketing version.

## Prepared candidate

- **Mugshot Luna QA 0.5.3 (18)**, `co.mugshot.app.dev`.
- Product source: `a52be2f4cbdb144d13cc846c908eab41513522f5`.
- Signed Debug build with the iOS 27.0 SDK succeeded.
- Main app, share extension, and widget versions, development signatures,
  provisioning expiry, and owner-device coverage were verified.
- Entitlements, app group, keychain identity, and backend configuration match
  the retained build 16 device package. Analytics remains disabled. The package
  contains no test bundle; credential exclusion checks passed.
- Debug library SHA-256:
  `f5c2fdda83bd28d2737b6b299ff8ff077e5b3801f71aeb2fb2b8dd05b62f57f6`.

The build, signed app, verification script, and package receipt remain private
under `.codex/premium-polish-iphone-2026-11-13/`, excluded from Git. Existing
[Simulator evidence](README.md) remains valid; the device package is configured
for the owner's existing development app rather than the isolated audit backend.

## Installation blocker

The paired iPhone 16 Pro reports **unavailable**. Requests for its installed-app
inventory fail with CoreDevice error 4016: trusted connectivity and device
services are unavailable. Retrying with both installed Xcode toolchains did not
restore access. The owner was asked to connect and unlock the phone.

Consequently, the current installed build could not be read, a fresh app/group
backup could not be taken, and installation and launch were not attempted.
No phone app, preferences, keychain, or stored user content was changed.

## Remaining delivery acceptance

1. Reconnect and read the installed development app identity.
2. Preserve the app and shared-container data in private backups before replacement.
3. Install build 18 in place, without uninstalling, clearing data, or fixture flags.
4. Compare durable file hashes before launch and after launch; record any expected
   runtime changes separately from loss or migration.
5. Confirm the installed build and normal foreground launch.

Installation/launch will establish development delivery only. Hands-on product
acceptance, unresolved dependency holds, and TestFlight acceptance remain separate.
No archive, export, upload, or TestFlight action was performed.
