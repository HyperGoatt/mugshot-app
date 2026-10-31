#!/bin/bash
# Full free local authoring-to-playback workflow, operated by Codex.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DESIGN="$ROOT/docs/design/weekly-pour-2026-10-31"
TARGET="${1:?Pass an existing detached fixture checkout}"
SIM="${MUGSHOT_RECAP_SIMULATOR:?Select the booted 402x874 iPhone 17 Pro Simulator}"
DERIVED="${MUGSHOT_RECAP_DERIVED:-/tmp/mugshot-weekly-pour-derived}"
"$DESIGN/prepare.sh" "$TARGET"
xcodebuild -project "$TARGET/testMugshot.xcodeproj" -scheme MugshotTests \
  -configuration Debug -destination "platform=iOS Simulator,id=$SIM" \
  -derivedDataPath "$DERIVED" -skipPackageUpdates \
  MUGSHOT_SUPABASE_URL=https://publication-fixture.invalid \
  MUGSHOT_SUPABASE_PUBLISHABLE_KEY=synthetic-key \
  MUGSHOT_POSTHOG_PROJECT_TOKEN= -quiet build
APP="$DERIVED/Build/Products/Debug-iphonesimulator/testMugshot.app"
python3 "$DESIGN/capture.py" "$APP" --simulator "$SIM"
python3 "$DESIGN/film.py" "$APP" --simulator "$SIM"
python3 "$DESIGN/boards.py"
HF="$ROOT/docs/previews/completion-2026-10-30/node_modules/.bin/hyperframes"
if [ ! -x "$HF" ]; then
  (cd "$DESIGN/review" && npm ci --ignore-scripts --no-audit --no-fund)
  HF="$DESIGN/review/node_modules/.bin/hyperframes"
fi
(cd "$DESIGN/review" && HYPERFRAMES_SKIP_SKILLS=1 HYPERFRAMES_NO_UPDATE_CHECK=1 HYPERFRAMES_NO_TELEMETRY=1 "$HF" check)
(cd "$DESIGN/review" && HYPERFRAMES_SKIP_SKILLS=1 HYPERFRAMES_NO_UPDATE_CHECK=1 HYPERFRAMES_NO_TELEMETRY=1 "$HF" render --workers 1 --fps 30 --quality standard --output review.mp4)
printf 'Native screens, native film and editable review rendered in %s\n' "$DESIGN"
