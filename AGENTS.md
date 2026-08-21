# Mugshot Repository Rules

- In every user-facing string and product document, use the ASCII spellings `cafe` and `cafes`.
- Never use an accented e in those words.

## Verification Policy

- Follow [`docs/VERIFICATION_POLICY.md`](docs/VERIFICATION_POLICY.md) for every change.
- Classify the change before running verification. Use the lowest tier that covers the actual regression risk.
- Small, local UI polish defaults to the three-minute fast path: inspect the diff and run one compile check. Do not launch Simulator, create test data, run UI tests, capture screenshots, build Release, or run the full test suite unless the change introduces a risk that requires it.
- Do not run a full end-to-end journey for copy, spacing, color, typography, icon, simple visibility, or isolated animation changes.
- Add one focused test only when behavior or logic changed and that test directly covers the change.
- Use full Simulator and end-to-end validation only for cross-screen journeys, navigation, persistence, networking, authentication, backend integration, media capture/upload, destructive actions, concurrency, migrations, or similarly high-risk behavior.
- A successful lower-tier check is the stopping condition. Do not repeat equivalent checks with another tool or expand the test scope without a concrete failure, uncertainty, or blast-radius reason.
- Debug and Release builds are not both routine. Run Release only for release gates, build settings, compiler/optimization issues, availability checks, packaging, or an explicit user request.
- For documentation-only changes, inspect the diff and formatting only; do not build the app.
- If verification will materially exceed the tier's expected time, tell the user why before starting the longer check.

## TestFlight Upload Handoff

- TestFlight is a manual release gate. Never archive, export, upload, or assign a build unless the user explicitly asks after local validation is complete.
- Before any TestFlight handoff, build and run the candidate on a local Simulator and on the user's connected iPhone. Report either gate as blocked instead of bypassing it.
- Keep prerelease candidates on the currently approved App Store marketing version unless the user explicitly approves a version bump. Increment build numbers because App Store Connect does not permit reusing a version/build pair.
- Every TestFlight archive, upload, or testing-group handoff must include a ready-to-paste **What to Test** blurb in the final response.
- Tailor the blurb to the exact version/build and its meaningful product changes. Lead with the primary new behavior, then name the most important regression paths and failure states.
- Keep the copy tester-facing, concise, and suitable for App Store Connect's 4,000-character field. Do not include implementation jargon, secrets, private identifiers, fabricated claims, or features that are not present in the uploaded build.
- Include explicit privacy or access-control expectations whenever the build changes sharing, authentication, user content, permissions, or public links.
- If the build has already been uploaded, report its processing status and current testing-group state alongside the blurb so the user can assign it without reconstructing release context.
- Use [`docs/TESTFLIGHT_UPLOAD_HANDOFF.md`](docs/TESTFLIGHT_UPLOAD_HANDOFF.md) as the reusable format.
