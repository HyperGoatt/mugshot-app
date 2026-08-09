# Mugshot App Store Connect and TestFlight submission package

Prepared: 2026-08-09

Release candidate: 0.5.1 (1)

Production bundle ID: `co.mugshot.app.testMugshot`

Apple Developer organization: `Candlewood Coffee LLC`

This is the copy-and-answer source for the first external TestFlight alpha. It
separates repository-proven facts from entries that require the Apple account
holder's identity, credentials, or legal decision. Do not invent values for
the bracketed fields.

## Inputs still required from Candlewood Coffee LLC

Everything else in this package is ready to paste. The account holder must
still supply or approve only these items:

1. Unlock the Mac and explicitly authorize Xcode to create the Apple
   Distribution certificate and production provisioning profiles.
2. Choose the legally accurate EU status: `Trader` or `Not a trader`.
3. Supply a monitored review contact first name, last name, direct phone with
   country code, and email.
4. Approve the published Privacy Policy, Terms, support address, and the company
   details Apple will display.
5. Supply the friend testers' TestFlight email addresses when invitations are
   ready to send.

The dedicated reviewer account is created and validated against production; its
password is stored in the Mac Keychain and is not committed to Git.

## App record

| App Store Connect field | Value |
| --- | --- |
| Platform | iOS |
| Name | Mugshot |
| Developer organization / seller | Candlewood Coffee LLC |
| Developer name, if Apple prompts on the first app | Candlewood Coffee LLC, unless the account holder intentionally chooses a registered trade name or DBA |
| Primary language | English (U.S.) |
| Bundle ID | `co.mugshot.app.testMugshot` |
| SKU | `MUGSHOT-IOS-001` (recommended permanent internal identifier) |
| User access | Full Access, unless the account holder intentionally limits the app to selected App Store Connect users |
| Version | `0.5.1` |
| Build | `1` |
| Primary category | Food & Drink (recommended) |
| Secondary category | Lifestyle (recommended) |
| Content Rights | Yes — Mugshot displays user-generated text/photos and third-party cafe/place information; certify only after confirming the Terms and data licenses grant the necessary rights |
| License Agreement | Apple's standard EULA; do not add a custom App Store Connect EULA for this alpha |

Confirm that the app name is available before creating the record. Apple
requires the record before build upload and may require the Account Holder to
accept the latest agreement first. The Apple ID generated for the record must
then replace the blank `MUGSHOT_APP_STORE_URL` build setting with the final App
Store URL before a later customer-facing release.

If Apple asks for the developer name because this is the organization's first
app, treat that as a durable public identity choice. `Candlewood Coffee LLC` is
the safe default provided here; use another name only if it is a registered
trade name Apple permits.

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
| Username | `app-review@mugshot.app` |
| Password | Retrieve the `Mugshot App Review` item for this username from the Mac Keychain immediately before submission |

The account was created and password sign-in was verified against production on
2026-08-09. It has a non-personal profile and one saved cafe. It does not
require 2FA, magic-link, or one-time-code access. Reverify the credentials
immediately before submission.

### Beta App Review notes

> Mugshot is an authenticated coffee journal with optional social sharing.
> Use the supplied reviewer account to open Feed, Map, Saved, Profile, and
> Settings. The account begins with one saved cafe and no personal content. To
> create a journal visit, tap Add, select or capture a non-sensitive coffee
> photo, select a cafe, enter the drink and rating details, choose visibility,
> and save. Location permission is optional; a cafe can be found by search
> instead. Photo-library or camera permission is requested only when the
> reviewer chooses that source. The app includes user-generated photos and
> text, a social feed, likes, comments, friend relationships,
> blocking/reporting controls, and account-deletion initiation in Settings.
> There are no purchases, paid features, advertisements, or non-exempt
> encryption. Privacy Policy: https://mugshotapp.co/privacy . Terms:
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

All three URLs returned HTTP 200 on 2026-08-09. An authorized representative of
Candlewood Coffee LLC must still approve the hosted policy,
retention/deletion statements, third-party disclosures, and contact address
before submission.

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
| Made for Kids | No |
| Override to Higher Age Rating | No, unless the final Terms or account policy sets a higher minimum age than Apple's calculated rating |

For the current coffee-journal product scope and clean reviewer seed, enter
`None` for every mature-content frequency field:

- Profanity or Crude Humor
- Horror/Fear Themes
- Alcohol, Tobacco, or Drug Use or References
- Medical or Treatment Information
- Health or Wellness Topics
- Mature or Suggestive Themes
- Sexual Content or Nudity
- Graphic Sexual Content and Nudity
- Cartoon or Fantasy Violence
- Realistic Violence
- Prolonged Graphic or Sadistic Realistic Violence
- Guns or Other Weapons
- Gambling
- Simulated Gambling
- Contests
- Loot Boxes

These answers describe Mugshot's intended and moderated experience; the
separate `User-Generated Content`, `Social Media`, and `Messaging and Chat`
answers disclose the user-content capabilities. Recheck the production seed at
submission time and save Apple's calculated global and regional ratings. With
`Social Media = Yes`, Apple's current iOS 26+ matrix should calculate at least
13+ globally and 16+ in Australia, but App Store Connect's live result is the
authority.

## EU Digital Services Act trader status

The account holder must choose the legally accurate status in App Store
Connect. This cannot be inferred from source code.

Apple's published factors make `Trader` the likely selection for an app offered
by an enrolled LLC in connection with its business, but Candlewood Coffee LLC
must make or legally confirm that classification.

- If distributing in the EU as a trader, provide and verify the required legal
  name, address, phone, and email shown by Apple. For an organization, Apple
  uses the D-U-N-S address and asks for a display phone number and email, payment
  account details, email/phone verification, and business/address evidence.
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
- [ ] Confirm that Candlewood Coffee LLC's legal entity details in Apple
      Developer and App Store Connect are current.
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
