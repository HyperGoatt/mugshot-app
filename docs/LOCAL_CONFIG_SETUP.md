# Local Config Setup

Date: 2026-07-01

Purpose: keep client-safe Supabase configuration local while allowing Xcode and Codex/XcodeBuildMCP to build the native app.

## Files

Tracked:

- `Config/Info.plist`
- `Config/SupabaseConfig.xcconfig`
- `Config/SupabaseConfig.local.xcconfig.example`

Ignored:

- `Config/SupabaseConfig.local.xcconfig`

## Setup

1. Copy the example file:

```text
Config/SupabaseConfig.local.xcconfig.example
```

2. Create:

```text
Config/SupabaseConfig.local.xcconfig
```

3. Fill in client-safe Supabase values:

```text
MUGSHOT_SUPABASE_URL = https:/$()/YOUR_PROJECT_REF.supabase.co
MUGSHOT_SUPABASE_PUBLISHABLE_KEY = sb_publishable_REPLACE_ME
```

The `https:/$()/...` form is intentional. In `.xcconfig` files, plain `https://` can be parsed as `https:` followed by a comment.

## Key Rules

- Use only client-safe Supabase keys in the iOS app.
- Prefer current Supabase publishable keys when available.
- A legacy anon key is still client-side/public, but do not treat it as secret app logic.
- Never use a service-role key.
- Never use an `sb_secret_...` key.
- Never commit `Config/SupabaseConfig.local.xcconfig`.

## How The App Reads Config

`Config/SupabaseConfig.xcconfig` is attached to the app target build configurations.

`Config/Info.plist` contains build-setting placeholders:

```text
MUGSHOT_SUPABASE_URL
MUGSHOT_SUPABASE_PUBLISHABLE_KEY
```

At build time, Xcode expands those placeholders from the ignored local config. At runtime, `SupabaseConfiguration` reads the values from `Bundle.main` or process environment.

## Verification

Safe checks:

- Build succeeds.
- The app opens to the auth screen instead of "Supabase config needed".
- The built app bundle does not contain `SupabaseConfig.local.xcconfig`.
- `Config/SupabaseConfig.local.xcconfig` is ignored by git.

Do not print local key values into logs, docs, screenshots, or final reports.
