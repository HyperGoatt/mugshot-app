# Mugshot App Store Connect and TestFlight submission package

Prepared: 2026-08-09

Release candidate: 0.5.1 (1)

Production bundle ID: `co.mugshot.app.testMugshot`

This is the copy-and-answer source for the first external TestFlight alpha. It
separates repository-proven facts from entries that require the Apple account
holder's identity, credentials, or legal decision. Do not invent values for
the bracketed fields.

## App record

| App Store Connect field | Value |
| --- | --- |
| Platform | iOS |
| Name | Mugshot |
| Primary language | English (U.S.) |
| Bundle ID | `co.mugshot.app.testMugshot` |
| SKU | `MUGSHOT-IOS-001` (recommended permanent internal identifier) |
| User access | Full Access, unless the account holder intentionally limits the app to selected App Store Connect users |
| Version | `0.5.1` |
| Build | `1` |
| Primary category | Food & Drink (recommended) |
| Secondary category | Lifestyle (recommended) |

Confirm that the app name is available before creating the record. Apple
requires the record before build upload and may require the Account Holder to
accept the latest agreement first. The Apple ID generated for the record must
then replace the blank `MUGSHOT_APP_STORE_URL` build setting with the final App
Store URL before a later customer-facing release.

## TestFlight test information

### Beta App Description

> Mugshot is a personal coffee journal for capturing a drink, remembering the
> cafe, and seeing your taste story grow. Save photo-backed visits, rate what
> stood out, revisit places on the map, and optionally share moments with
> friends. This early alpha is focused on the complete journal loop,
> reliability, privacy controls, and the foundations of the social experience.

### Feedback Email

`support@mugshot.app`

### What to Test

> Thanks for joining Mugshot's first alpha. Please focus on signing up or
> signing in, adding a visit with a photo and cafe, editing and reopening that
> visit, browsing Feed and Map, saving a cafe, viewing your profile and taste
> insights, and trying likes, comments, friends, notifications, and sharing
> where available. Please report confusing states, incorrect cafe details,
> missing or duplicated photos, slow or failed saves, notification issues, and
> anything that does not survive an app relaunch. Also try denying location or
> photo access so we can improve those recovery paths. Never use sensitive
> personal information in this alpha.

### TestFlight App Review contact

| Field | Required entry |
| --- | --- |
| First name | `[ACCOUNT HOLDER OR REVIEW CONTACT FIRST NAME]` |
| Last name | `[ACCOUNT HOLDER OR REVIEW CONTACT LAST NAME]` |
| Phone | `[DIRECT PHONE WITH COUNTRY CODE]` |
| Email | `[MONITORED REVIEW CONTACT EMAIL]` |

These details are for Apple review contact, not tester feedback. They must be
real and monitored during review.

### Sign-in information

The app requires authentication, so provide a durable reviewer account that
does not expire and does not require reviewer access to a personal inbox.

| Field | Required entry |
| --- | --- |
| Sign-in required | Yes |
| Username | `[DEDICATED APPLE REVIEW ACCOUNT EMAIL]` |
| Password | `[DEDICATED APPLE REVIEW ACCOUNT PASSWORD]` |

The account should start with enough curated, non-personal data to exercise
Feed, Map, Saved, Profile, and a visit detail. Verify the credentials on the
production backend immediately before submission. Do not place 2FA, magic-link,
or one-time-code requirements in Apple's path.

### Beta App Review notes

> Mugshot is an authenticated coffee journal with optional social sharing.
> Use the supplied reviewer account to open the existing journal, Feed, Map,
> Saved, Profile, and Settings surfaces. To create a visit, tap Add, select or
> capture a non-sensitive coffee photo, select a cafe, enter the drink and
> rating details, choose visibility, and save. Location permission is optional;
> a cafe can be found by search instead. Photo-library or camera permission is
> requested only when the reviewer chooses that source. The app includes
> user-generated photos and text, a social feed, likes, comments, friend
> relationships, blocking/reporting controls, and account-deletion initiation
> in Settings. There are no purchases, paid features, advertisements, or
> non-exempt encryption. Privacy Policy: https://mugshotapp.co/privacy . Terms:
> https://mugshotapp.co/terms . Support: support@mugshot.app .

Use these notes only after production account deletion and all named moderation
paths have passed their release gates. If a feature is withheld from the build,
remove that claim before submission.

## Export compliance

- The packaged Info.plist declares `ITSAppUsesNonExemptEncryption = false`.
- App Store Connect answer: the app does not use non-exempt encryption.
- No encryption documentation is expected for this release unless the shipped
  dependencies or cryptographic behavior change before upload.

## App Privacy answers

Use the packaged `testMugshot/PrivacyInfo.xcprivacy` and
`docs/app-store-submission-data-inventory.md` as the source of truth.

| App Privacy data type | Linked to user | Tracking | Purpose |
| --- | --- | --- | --- |
| Email Address | Yes | No | App Functionality |
| Name | Yes | No | App Functionality |
| User ID | Yes | No | App Functionality; Analytics |
| Device ID | Yes | No | App Functionality |
| Precise Location | Yes | No | App Functionality |
| Photos or Videos | Yes | No | App Functionality |
| Other User Content | Yes | No | App Functionality |
| Product Interaction | Yes | No | Analytics |
| Other Usage Data | Yes | No | Analytics |

- Tracking: No.
- Tracking domains: None.
- Privacy Policy URL: `https://mugshotapp.co/privacy`.
- User Privacy Choices URL: leave blank unless a dedicated, accurate page is
  published; the in-app controls alone do not create an App Store URL.
- Support URL: `https://mugshotapp.co/`.
- Terms URL for review notes: `https://mugshotapp.co/terms`.

All three URLs returned HTTP 200 on 2026-08-09. The legal owner must still
approve the hosted policy, retention/deletion statements, third-party
disclosures, and contact address before submission.

## Age rating questionnaire

Answer from the behavior in the uploaded build. Apple calculates the global
and region-specific ratings after the questionnaire; do not enter or promise a
guessed final rating.

| Capability | Evidence-based answer |
| --- | --- |
| Parental Controls | No |
| Age Assurance | No, unless an age-assurance flow is added and verified before upload |
| Unrestricted Web Access | No |
| User-Generated Content | Yes |
| Social Media | Yes; Feed, likes, comments, friends, sharing, and discovery interact with or distribute user content |
| Social Media Disabled for Users Under 13 | No; the app does not currently call Apple's Declared Age Range API to gate social capabilities |
| Messaging and Chat | Yes; Apple's definition includes public posting, and the app supports comments |
| Advertising | No |
| Made for Kids | Not Applicable |
| Override to Higher Age Rating | Not Applicable unless the final Terms or account policy sets a higher minimum age than Apple's calculated rating |

For every content-frequency question, inspect the production moderation rules
and the final seeded reviewer content at submission time. Do not answer `None`
merely because the app owner does not create that content: user-generated text
and photos can affect the truthful response. Save Apple's calculated rating and
regional results in this audit after completing the live form.

## EU Digital Services Act trader status

The account holder must choose the legally accurate status in App Store
Connect. This cannot be inferred from source code.

- If distributing in the EU as a trader, provide and verify the required legal
  name, address, phone, and email shown by Apple.
- If not a trader, make that declaration knowingly and retain the supporting
  rationale.
- Record the chosen status and verification result here before external review:
  `[EU TRADER STATUS AND DATE]`.

## First external alpha group

| Setting | Value |
| --- | --- |
| Internal group | `Alpha Internal` (create first; Apple requires an internal group before an external group) |
| External group | `Alpha Friends` |
| Distribution | Email invitations for the first cohort; avoid a public link until support and moderation load are understood |
| Build | 0.5.1 (1), after processing and export-compliance clearance |
| Automatic distribution | Off for the first build; manually release after TestFlight App Review approval |

Invite only after the production backend, deletion gate, signed archive, and
processed build are verified. Add each friend using the email address they want
to use with TestFlight:

1. `[FRIEND TESTER EMAIL 1]`
2. `[FRIEND TESTER EMAIL 2]`
3. `[FRIEND TESTER EMAIL 3]`

The first external build of the version requires TestFlight App Review. Submit
the build with the description, What to Test, contact, credentials, and review
notes above; invite friends after Apple approves the group build.

## Execution checklist

- [ ] Account Holder accepts any pending Apple Developer agreement.
- [ ] Create the iOS app record using the fields above and record its Apple ID.
- [ ] Set the final `MUGSHOT_APP_STORE_URL` in the release build configuration.
- [ ] Complete App Privacy exactly as mapped above.
- [ ] Complete the live age-rating questionnaire; record calculated and
      regional results.
- [ ] Complete and verify EU trader status.
- [ ] Add real review contact details and verified, durable reviewer
      credentials.
- [ ] Create `Alpha Internal`, then `Alpha Friends`.
- [ ] Upload the signed 0.5.1 (1) archive and wait for processing.
- [ ] Confirm export compliance, attach the build, and submit the first external
      build for TestFlight App Review.
- [ ] After approval, invite the named friend testers and confirm invitation
      delivery.

## Apple references

- [Create the app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [Provide TestFlight information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information)
- [Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [Manage App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Set an age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)
- [Age-rating values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)
