# Mugsy reminder native review — 2026-11-25

Historical native evidence for the [current implementation](../../MUGSY_REMINDERS.md).

Unaltered iOS 27 Simulator screenshots are exported from focused XCTest results.
The preferences view and card use the production SwiftUI implementations with a
fictional account and injected service. No real backend, push enrollment, private
journal data, or analytics is used in this review. Every PNG hash and generating
test is recorded in [captures.json](captures.json).

[Open the gallery](index.html). Saving with the injected service proves native
state handling only. Provider acceptance, physical display, production data and
TestFlight remain separate evidence.

The initial six captures exercise the isolated settings service. Captures 07–09
were added after the physical Feed overlap was found; they exercise the real
MainTab/Journal shell with fictional local data and prove the card scrolls inline.
The focused integration test passes from source `cded57f`.
