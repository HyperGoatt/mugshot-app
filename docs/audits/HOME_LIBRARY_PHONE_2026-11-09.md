---
document_type: historical
status: installed-and-launch-verified
date: 2026-11-09
---

# Home library and repeat brewing — iPhone installation

Current behavior: [Home recipes and brewing](../HOME_RECIPES_IMPLEMENTATION.md).
The owner authorized this development install after the
[native and Simulator verification](HOME_LIBRARY_AND_BREWING_2026-11-09.md).
This follow-up changes delivery evidence only.

**Mugshot Luna QA 0.5.3 (9)**, `co.mugshot.app.dev`, replaced build 8 in place
on the owner's iPhone 16 Pro / iOS 27.0.1. Source is
`b9a7f8dbc76633613739717f1cf01e176a8aeaab`; the signed debug library SHA-256 is
`02fa2d0133bf8e6d800f993c84011131bc7c0f5272d0de1fd410cdbbc40ff45a`.
The development build uses the same bundle, app group and sandbox entitlement.
Deep signature verification, both extension signatures and versions, and
credential exclusion pass. Analytics is disabled.

The device reported build 9 and a successful foreground launch. The app process
was still running at the follow-up check and the screen showed normal app
navigation. All **40 Application Support files and one preferences file**
matched their private backups byte for byte both before and after the launch.
The shared container inventory was unchanged through installation; no Documents
folder was present. Backups and the owner screen capture remain local.

This verifies installation and launch. The 185 native cases and 16 focused
Simulator journeys remain separate evidence for Home behavior. No backend change,
merge, or TestFlight action occurred. Draft PR #109 remains held.

To try the new flow on the phone, open **Saved → Home library** for recipe
capture, beans and gear; use **Add → Home** for guided making or quick log.
Open a saved Home sip with measurements to try **Compare your brew → Make again**.
