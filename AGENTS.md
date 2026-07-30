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
