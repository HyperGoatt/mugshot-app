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
| Current location and saved cafe coordinates | Find nearby cafes and associate a visit or saved item with a cafe | Apple MapKit for real-time search; Supabase stores the selected cafe and its coordinates | Deny location and type/search a cafe instead; edit or delete the associated content | Precise location; account-linked; app functionality; not tracking |
| Product interaction and other usage events | Measure feature use and improve reliability | PostHog, identified by the account UUID | Sign out or delete account | Usage data; account-linked; analytics; not tracking |

## Submission gate

- [ ] `https://mugshotapp.co/privacy` resolves publicly and is the final,
      legally approved policy.
- [ ] `https://mugshotapp.co/terms` resolves publicly and matches the in-app
      summary.
- [ ] Settings exposes the Privacy Policy, Terms, selectable support email,
      mail fallback, and in-app Delete Account initiation.
- [ ] The App Privacy answers match the table above and
      `testMugshot/PrivacyInfo.xcprivacy`. The release declares no tracking;
      email, name, user ID, device ID, precise location, photos/videos, other
      user content, product interaction, and other usage data are linked to the
      account for app functionality or analytics as recorded in the manifest.
- [ ] The legal owner has confirmed retention, deletion timing, third-party
      service disclosures, and the final contact address.
- [ ] Test account deletion removes both owner storage prefixes, relational
      records, and session access in a non-production project.
