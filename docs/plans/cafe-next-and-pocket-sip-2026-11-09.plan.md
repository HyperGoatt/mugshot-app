# Cafe detail, The Next Sip and Pocket Sip

## Goal

Integrate the approved Mugshot Lab experience into the existing iOS app. A cafe opens at full height from Map or Saved. A returning visitor can start from their latest order, and a person with coffee photos can keep a private draft from Add or directly from Photos.

## Implementation

1. Give Map and Saved a common cafe layout with a source-aware Back button, a clear primary action, and the cafe's existing actions and history further down. Cover first visits, repeatable orders, and orders marked Wouldn't reorder.
2. Create The Next Sip as a new private draft. Use the latest eligible order at that cafe owned by the active person. Copy the drink and order details, date the draft today, and keep today's photo, rating, and reflection empty. Keep the original sip accessible.
3. Put Pocket Sip in Add with the native multi-photo picker. Let Photos hand off images through the existing Save to Mugshot extension. Send both into the same account-scoped draft library and provide confirmation only after local storage succeeds. Preserve place sharing.
4. Verify both cafe routes and both photo routes on Simulator. Test ownership, cancellation, bad inputs, handoff retry and persistence across relaunch. Run the repository documentation and applicable static checks before publishing the feature branch.

## Documentation impact

This changes product behavior, local data ownership, privacy, and the existing share extension's activation contract. Update the changelog, current product status, real data flow, and sharing guidance. Keep the existing app group and signing configuration. No Supabase changes are required.

## Verification

- The signed Debug Simulator build contains the app and the existing share extension. The app and extension carry the same simulated app-group entitlement.
- The iPhone 17 Pro Simulator on iOS 27.0 passed 44 focused unit tests and eight UI tests. The UI tests exercised Map pin open and Back, Saved handoff, the original sip, the first-visit and declined-order states, accessibility text size, Pocket Sip cancellation, and repeat draft reopening. A follow-up test passed after editing the repeated order details and reopening that draft after termination.
- A separate iPhone 17 Pro Simulator on iOS 26.3.1 used local fixtures to open the cafe from Map and Saved, add one photo to the repeat draft, save a two-photo Pocket Sip through the native Add picker, and share three distinct images from Photos while Mugshot was terminated. Relaunch preserved all three drafts. The imported photos matched the three staged JPEGs in order, and Mugshot acknowledged the handoff after committing the private draft. A Safari URL share opened the existing Save cafe search flow.
- Storage coverage includes owner switches, stale extension sessions, account deletion, cancellation, invalid photos, ordered bytes, retry after a failed commit, and replay after draft edits or cleanup.

## Release boundary

This is a Simulator-verified candidate stacked on the Home library branch. Authenticated production reads, signed-device acceptance, and TestFlight are separate release gates.
