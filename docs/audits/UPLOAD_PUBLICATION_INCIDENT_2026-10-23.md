---
document_type: historical
status: evidence
date: 2026-10-23
---

# Interrupted cafe publication incident

Current implementation: [data flow](../REAL_DATA_FLOW_STATUS.md#interrupted-photo-publication--2026-10-23).

## Evidence

The affected account and exact stable visit were matched across production
Supabase, PostHog project 521217, source, and a read-only copy of the connected
development app's protected outbox. No session credentials or photo pixels were
read. All times below are EDT on October 23.

- 11:23:07: `sip_publish_attempted`, development version 0.5.3 (8), Wi-Fi.
- 11:25:11: `sip_publish_failed`, `network`, `protected_retry`, immediately
  followed by `sip_recovery_resumed`. Supabase logged HTTP 522 for
  `ensure_cafe_session_v1` at 11:25:26.
- 11:27:44: the first photo upload returned HTTP 200. The earlier partial object
  was later replaced; current Storage timestamps alone are not the first
  successful-upload timestamps.
- 11:53:42: automatic recovery successfully ensured/attached the cafe session
  and saved cafe experience. Two photo requests then returned HTTP 200.
- 11:53:45: PostHog reported open/background lifecycle transitions. Current
  Storage contained two objects; the outbox expected three and remained at
  `visitCreated`, with no photo-batch or finalization receipt. The visit remained
  `uploading`, private, and had zero photo attachment rows. The frozen requested
  audience was Everyone. No `sip_published` event was found in the inspected
  incident window.
- 12:41:47: after the owner unlocked the connected iPhone, reopening the
  existing development app let its normal queue retry. Read-only production
  verification confirmed the same visit complete, all three photo attachment
  rows present, and the originally requested Everyone audience applied. No
  replacement post or administrative publication write was used. File metadata
  also confirmed all three protected local JPEGs were readable, nonempty files.
  A subsequent preferences read confirmed the owner's pending outbox was empty.

The initial trigger is a confirmed request/network timeout. Logs do not prove
the underlying gateway/network cause or the exact client-side third-photo
failure. The matching interruption timeline and source prove recovery
weaknesses: immediate inactivity cancellation, all-or-nothing photo progress,
deletion of already uploaded objects after a later batch failure, and transport
resource waits without an app-specific bound. The stuck post is a reliability
bug, not successful recovery.

Concurrent Home workspace writes returned `Immutable recipe version conflict`
and HTTP 409. They are a separate observed sync problem: cafe/session requests
and Storage uploads succeeded alongside them. No causal link to this post's
third-photo interruption is established; no recipe or workspace data was
rewritten as part of this repair.

## Patch and validation

Both publication paths now durably checkpoint each acknowledged photo and
retain completed objects for retry. Receipts belong to the exact account, visit,
and frozen object plan; stale workers cannot erase them. Replaced plans and
authoritatively missing remote visits reset progress. Legacy records remain
decodable. One-shot editing keeps its existing rollback behavior.

The shared HTTP session has a 30-second idle request timeout and 90-second
resource limit. A finite iOS background lease surrounds foreground publication
and automatic recovery. Brief inactivity does not cancel the visit pass;
expiration, task cancellation, and account changes still stop it.

Tier 3 full-static verification passed: 13 checks, zero failures or skips,
including the app/unit/UI test compile, local backend contracts, and documentation
validation. The consolidated iOS 27 Simulator checkpoint passed all 18 focused
`PendingVisitRecoveryTests` and `AutomaticSipRecoveryCoordinatorTests`, with zero
failures or skips. It exercises a third-photo transport failure, retained
acknowledgements after reload/stale saves, retry of only unfinished work,
poster/order preservation, replaced-plan reset, account isolation, inactivity,
and cancellation. The transport fixture uses a synthetic `.invalid` host and
never writes production data. Result bundle:
`test_sim_2026-10-23T16-42-21-647Z_pid52284_c20b82bd.xcresult`.
Real iOS suspension/expiration of the patched candidate on hardware remains an
owner-promoted acceptance boundary.

Administrative production access was read-only. The existing app's retry
completed the owner's already requested publication through normal authenticated
contracts. No schema, RLS, bucket, marketing version, TestFlight build, or
testing-group state changed. Recovery of this post used the original app and
does not prove the patch has been installed or physically accepted.
