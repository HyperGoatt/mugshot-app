# Release data cleanup

Production starts clean. This directory separates discovery from deletion so
release cleanup cannot accidentally target real journals.

1. Run `report.sql` with an explicit QA-account allowlist and/or known
   smoke-record IDs.
2. Export the returned IDs, owners, captions, and photo URLs for an admin to
   approve. Keep that approval with the release record.
3. Paste only approved visit IDs into `approved-delete.sql`, inspect its
   verification `SELECT`, then run it with a production-admin session.
4. Re-run `report.sql`; it must return no unapproved candidates before the
   release gate passes.

`approved-delete.sql` deletes only Storage paths matching the approved visit
and owner. It does not use broad text matching and does not touch profile media.
For a full test-account removal, use the authenticated `delete-account` Edge
Function after explicit account-owner approval.
