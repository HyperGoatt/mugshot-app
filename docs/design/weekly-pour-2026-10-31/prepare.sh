#!/bin/bash
# Prepare an isolated native design harness; never edits the active app checkout.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TARGET="${1:?Pass a detached fixture checkout}"
python3 "$ROOT/scripts/prepare-device-motion-qa.py" "$TARGET" --bundle-id co.mugshot.app.testMugshotUITests
cp "$ROOT/docs/design/weekly-pour-2026-10-31/source/WeeklyPourPrototype.swift" \
   "$TARGET/testMugshot/Views/Developer/MugshotCompletionPreviewHost.swift"
printf 'Prepared native recap prototype in %s\n' "$TARGET"
