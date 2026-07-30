# Mugshot Auth Audit and Delivery Plan

Date: 2026-07-30

## Goal

Ship a production-ready Supabase Auth path for:

- email/password signup, confirmation, sign-in, and recovery;
- native Sign in with Apple;
- Sign in with Google through Supabase OAuth;
- branded signup-confirmation and password-reset email templates.

The implementation must keep identity and session handling in Supabase Auth, preserve the app's existing account-scoped data isolation, and avoid collecting or exposing credentials or unnecessary personal data.

## Pre-implementation audit

### What is already sound

- The app has one centralized `AuthService` backed by `supabase-swift`.
- Email signup supplies `mugshot://auth/callback`.
- Password reset supplies `mugshot://auth/recovery`.
- Callback routing accepts only the exact Mugshot scheme, host, and known paths.
- Cold-launch and warm-launch callbacks are queued behind session restoration and consumed once.
- Apple uses the native AuthenticationServices flow with a cryptographic nonce and passes the ID token to Supabase.
- Google uses Supabase's OAuth flow with `openid email profile`.
- Supabase identity metadata determines the available account-verification methods.
- Apple full name is captured on the first authorization and used only to bootstrap the Mugshot profile.
- Public profile creation is bound to the authenticated user's ID and protected by RLS.
- Email confirmation is required, secure email change is enabled, anonymous signup is disabled, and manual identity linking is disabled.

### Findings to remediate

| Priority | Finding | Impact |
| --- | --- | --- |
| P0 | `mugshot://auth/callback` and `mugshot://auth/recovery` are absent from the hosted redirect allowlist. | Confirmation, recovery, and Google OAuth cannot reliably return to the app. |
| P0 | Apple and Google are disabled in hosted Supabase Auth. | Both buttons currently lead to provider failures. |
| P0 | Google Cloud has no Mugshot OAuth client. | Supabase Google OAuth cannot be enabled without a Web client ID and secret. |
| P0 | Custom SMTP is disabled. | Supabase's built-in mailer is rate-limited and is not a production delivery channel. |
| P1 | The reset-password email is the default Supabase template. | Recovery email is not on brand. |
| P1 | Password policy is six characters and leaked-password protection is disabled. | New passwords do not meet a reasonable production baseline; Supabase's security advisor flags this. |
| P1 | Email addresses are normalized for sign-in/signup but not reset/resend. | Equivalent email input can behave inconsistently. |
| P2 | Sign-in and account-creation validation share one six-character rule. | Raising the signup minimum could accidentally lock out legacy accounts unless sign-in remains backward compatible. |
| P2 | Password-change security notifications are disabled. | A user may not be alerted after a credential change. This is recommended follow-up, not a blocker for the requested flows. |
| P2 | CAPTCHA is disabled. | Abuse protection is weaker. Enabling it requires a separate CAPTCHA provider and client integration. |

The hosted project contains five email identities and no Apple or Google identities. No user emails, tokens, provider secrets, or message contents are recorded in this audit.

## Implementation plan

1. Version the branded confirmation and recovery email templates in this audit folder.
2. Add the two exact iOS redirect URLs to the Supabase allowlist.
3. Enable native Apple Auth for the Simulator and device bundle IDs.
4. Use the existing dedicated Mugshot Google Cloud project, register Supabase's callback URL, and enable Google in Supabase.
5. Apply the branded confirmation and recovery templates in Supabase.
6. Configure production SMTP if a verified sender and provider credentials are available; otherwise leave a precise, non-destructive release blocker.
7. Raise the new-password minimum to eight characters, enable leaked-password protection, and keep legacy email sign-in backward compatible.
8. Centralize and test password/email normalization behavior in the iOS auth layer.
9. Run the Tier 3 no-Simulator gate, focused auth tests, Supabase security checks, and one Tier 4 Simulator acceptance session.

## Implementation status

| Area | Status | Evidence or remaining requirement |
| --- | --- | --- |
| Redirects | Complete | Hosted allowlist includes `mugshot://auth/callback` and `mugshot://auth/recovery`. |
| Email confirmation | Complete | Confirmation remains required. The hosted subject and HTML use the versioned Mugshot template in this folder, and a safe plus-addressed signup test was reported delivered by Resend. |
| Password recovery | Complete | The hosted subject and HTML use the versioned Mugshot template in this folder, the app enforces the new-password policy, and a recovery request for an existing safe account was reported delivered by Resend. |
| Apple | Complete | Hosted Apple Auth is enabled for `co.mugshot.app.testMugshot` and `co.mugshot.app.testMugshot.dev` using Supabase's native token flow. |
| Google | Complete | The existing Google Cloud project has a Web OAuth client named `Mugshot Supabase Auth`, its redirect URI is Supabase's exact callback, the credentials are stored only in the hosted provider configuration, and the external OAuth app is published to production. |
| Google trust branding | Under Google review | Google Auth Platform has Mugshot's logo, public company/home page, privacy policy, terms, and `mugshotapp.co` authorized domain. Domain ownership is verified in Google Search Console and the free brand-verification request is submitted. Google will continue showing the Supabase project ID until the review is approved and the branding is published. |
| Password security | Complete | Hosted minimum is eight characters, leaked-password protection and secure password change are enabled, and legacy six-character sign-in remains accepted by the client. |
| SMTP | Complete on Resend Free | Supabase custom SMTP is saved with `smtp.resend.com:465`, sender `Mugshot <no-reply@auth.mugshotapp.co>`, and a Resend sending-only key restricted to `auth.mugshotapp.co`. Spaceship DNS contains the required DKIM and return-path SPF records plus monitoring-only DMARC, while the existing SpaceMail MX, SPF, and DKIM records remain unchanged. Resend verifies the domain, and both confirmation and recovery messages were reported delivered. The current [Resend Free plan](https://resend.com/docs/knowledge-base/account-quotas-and-limits) ceiling is 100 emails per day and 3,000 per month; monitor usage and upgrade before production volume approaches either limit. |
| iOS maintenance | Complete | Email normalization and password rules are centralized in `AuthService`; one focused test covers them and the callback constants. |

## Verification record

- The repository Tier 3 static gate passed: 11 checks passed, none failed, and one optional parser check was skipped because its optional dependency is absent.
- The focused auth test ran as exactly one selected test and passed.
- Two Debug Simulator build-and-launch checks passed; the second completed without diagnostics.
- A signed-out UI-testing launch showed Google, Apple, and email entry points plus the eight-character account-creation copy. No provider flow was submitted and no test user was created.
- The Simulator was returned to a normal app launch afterward.
- The hosted public Auth settings report signup enabled, email confirmation required, and email, Apple, and Google enabled.
- The Google authorization endpoint returns `302` to `accounts.google.com` using the Mugshot callback, without initiating a user login.
- The Supabase security advisor no longer reports `auth_leaked_password_protection`.
- `auth.mugshotapp.co` is verified for sending in Resend. Its DKIM, return-path MX/SPF, and root DMARC records resolved from Spaceship's authoritative nameserver, Cloudflare DNS, and Google Public DNS.
- Supabase custom SMTP remained enabled after a hard reload with the intended sender, host, port, and username.
- A live password-recovery request and a safe plus-addressed signup request both returned HTTP 200 from Supabase Auth and were reported delivered in Resend.
- A second disposable plus-addressed account proved the complete recovery mutation without touching an existing account: its branded confirmation link returned to `mugshot://auth/callback`, its branded recovery link returned to `mugshot://auth/recovery`, Supabase accepted the password update for the same user, the old password then returned HTTP 400, and the new password returned HTTP 200.
- Both temporary signup users were deleted after their delivery and recovery checks. A credential exposed during browser-state verification was rotated immediately, replaced in Supabase, and deleted from Resend before the delivery tests.
- Google Auth Platform saved Mugshot's logo, `https://mugshotapp.co/company` home page, privacy and terms URLs, and the `mugshotapp.co` authorized domain.
- A root TXT record was added in Spaceship DNS and Google Search Console confirmed ownership of `mugshotapp.co`. The record must remain in DNS to preserve verified ownership.
- Google's automated brand check could not interpret the client-rendered home page. The existing public company page visibly names Mugshot, explains its purpose, and links its privacy policy and terms, so a documented manual review request was submitted. Google Verification Center now reports that branding is under review.
- A raw-HTML fallback was prepared and its production build passed in the connected Lovable project, but it was intentionally not published because Lovable warned that publishing on the current plan would reintroduce a visible `Edit with Lovable` badge.

## Acceptance matrix

| Flow | Deterministic evidence | Runtime or hosted evidence |
| --- | --- | --- |
| Existing email user signs in | Sign-in validation does not enforce the new signup minimum | App reaches signed-in state |
| New email user signs up | Eight-character policy and normalized email | Branded confirmation is issued with the app callback |
| Confirmation callback | Exact-route tests and single-consumption tests | Callback opens Mugshot and restores the confirmed session |
| Password recovery | Eight-character policy, matching passwords, normalized email | Branded reset email opens the recovery screen and password update succeeds |
| Apple | Nonce and provider-mapping tests | Supabase accepts native Apple audience for both bundle IDs |
| Google | Supabase OAuth callback and provider configuration inspection | Google consent returns through Supabase and signs in to Mugshot |
| Session isolation | Existing auth-operation and account-scope tests | Sign-out clears the authenticated local scope |

Resend confirmed delivery to the real inbox provider, and a separate disposable account completed confirmation and password recovery end to end. No existing user's password was changed. Apple system authorization and final Google consent still require interactive safe-account acceptance testing. The temporary users created for delivery and recovery verification were removed immediately afterward.

## Google consent-screen trust options

- **Google brand verification:** Free and preserves the current Supabase OAuth flow. The logo, public URLs, and authorized domain are configured, domain ownership is verified, and the request is under Google review. After approval, the reviewed draft branding must be published within Google's allowed window.
- **Supabase custom domain:** Replaces the project hostname with a Mugshot-controlled hostname such as `auth.mugshotapp.co`, but it is a paid Supabase add-on (currently about $10 per month).
- **Supabase vanity subdomain:** `mugshot.supabase.co` is currently available on the project's Pro plan without a separate add-on, but the feature is experimental. Activation makes Auth stop functioning on the old project hostname, so it was not enabled because released or installed builds may still use that hostname.
