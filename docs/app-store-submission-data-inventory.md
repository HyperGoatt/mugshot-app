# Mugshot App Privacy submission checklist

Review this inventory against the final hosted Privacy Policy and App Store
Connect before uploading a release. It is a launch checklist, not legal advice.

| Data category | Why Mugshot processes it | Stored/processed by | User control | App Privacy review |
| --- | --- | --- | --- | --- |
| Account email | Sign in, session recovery, account support | Supabase Auth | Sign out or delete account | Account-linked contact information |
| User ID and session tokens | Authenticate and enforce ownership/access rules | Supabase Auth / Postgres RLS | Sign out or delete account | Identifiers; account-linked |
| Profile fields: display name, username, bio, location, favorite drink, links, avatar | Show the user’s chosen identity and preferences | Supabase Postgres and `profile-media` | Edit profile or delete account | User content / identifiers as applicable |
| Visit photos | Journal covers and user-selected sharing | Supabase Storage `visit-photos` | Per-visit audience, delete visit, or delete account | User content; account-linked |
| Captions, private notes, ratings, drink details | Save the personal coffee journal and taste insights | Supabase Postgres | Edit/delete visit or delete account | User content; account-linked |
| Likes, comments, saved cafes | Lightweight social feedback and personal cafe library | Supabase Postgres | Remove the action or delete account | User content; account-linked |
| Cafe/map searches and requested location | Find a cafe while creating a visit | Apple MapKit on-device/service request; selected cafe is stored with a visit | Deny location; type/search a cafe instead | Confirm precise/coarse location collection and linkage based on final behavior |

## Submission gate

- [ ] `https://mugshotapp.co/privacy` resolves publicly and is the final,
      legally approved policy.
- [ ] `https://mugshotapp.co/terms` resolves publicly and matches the in-app
      summary.
- [ ] Settings exposes the Privacy Policy, Terms, selectable support email,
      mail fallback, and in-app Delete Account initiation.
- [ ] The App Privacy answers match the table above, including whether each
      category is linked to identity and whether it is used for tracking.
- [ ] The legal owner has confirmed retention, deletion timing, third-party
      service disclosures, and the final contact address.
- [ ] Test account deletion removes both owner storage prefixes, relational
      records, and session access in a non-production project.
