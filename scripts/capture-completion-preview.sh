#!/bin/bash
# Reproduce the actual SwiftUI inspection route. Never targets physical devices.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-expressive}"
case "$MODE" in expressive|reduced|large) ;; *) echo 'Use expressive, reduced, or large.' >&2; exit 2 ;; esac
SIM="${MUGSHOT_PREVIEW_SIMULATOR:-$(xcrun simctl list devices booted -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[x["udid"] for v in d["devices"].values() for x in v if x.get("state")=="Booted" and "iPhone" in x["name"]]; print(a[0] if a else "")')}"
if [ -z "$SIM" ]; then echo 'No booted iPhone Simulator; select/boot one with XcodeBuildMCP first.' >&2; exit 2; fi
DERIVED="${MUGSHOT_PREVIEW_DERIVED:-/tmp/mugshot-completion-preview-derived}"
APP="${MUGSHOT_PREVIEW_APP:-$DERIVED/Build/Products/Debug-iphonesimulator/testMugshot.app}"
if [ -z "${MUGSHOT_PREVIEW_APP:-}" ]; then
  xcodebuild -project "$ROOT/testMugshot.xcodeproj" -scheme MugshotTests -configuration Debug \
    -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$DERIVED" \
    -disableAutomaticPackageResolution -skipPackageUpdates \
    MUGSHOT_SUPABASE_URL=https://publication-fixture.invalid \
    MUGSHOT_SUPABASE_PUBLISHABLE_KEY=synthetic-key MUGSHOT_POSTHOG_PROJECT_TOKEN= -quiet build
fi
python3 - "$APP/Info.plist" <<'PY'
import plistlib,sys,urllib.parse
with open(sys.argv[1],'rb') as f: info=plistlib.load(f)
assert urllib.parse.urlparse(info.get('MUGSHOT_SUPABASE_URL','')).hostname == 'publication-fixture.invalid', 'Refusing non-fixture app'
assert not info.get('MUGSHOT_POSTHOG_PROJECT_TOKEN'), 'Refusing enabled analytics'
assert info.get('CFBundleIdentifier') == 'co.mugshot.app', 'Unexpected preview bundle'
PY
OUT="$ROOT/docs/previews/completion-2026-10-30/assets"
mkdir -p "$OUT"
RAW="$(mktemp -d /tmp/mugshot-native-preview.XXXXXX)"
ARGS=(--ui-testing --ui-testing-completion-motion-design-qa)
if [ "$MODE" = reduced ]; then ARGS+=(--ui-testing-reduce-motion); fi
if [ "$MODE" = large ]; then ARGS+=(--ui-testing-reduce-motion --ui-testing-accessibility-xxxl --ui-testing-completion-quiet-week); fi
xcrun simctl install "$SIM" "$APP"
xcrun simctl terminate "$SIM" co.mugshot.app 2>/dev/null || true
xcrun simctl io "$SIM" recordVideo --codec=h264 "$RAW/native.mp4" > "$RAW/record.log" 2>&1 &
RECORDER=$!
trap 'kill -INT "$RECORDER" 2>/dev/null || true' EXIT
sleep 1
xcrun simctl launch "$SIM" co.mugshot.app "${ARGS[@]}"
sleep 6
kill -INT "$RECORDER"
wait "$RECORDER" || true
trap - EXIT
NAME="$MODE"
if [ "$MODE" = expressive ]; then NAME=completion; fi
# Trim only the system launch using a fixed background pixel from this fixture.
# The approved cream must be present; never silently deliver an empty recording.
START=$(python3 - "$RAW/native.mp4" <<'PYCODE'
import subprocess,sys
result=subprocess.run(['ffmpeg','-v','error','-i',sys.argv[1],'-vf',
 'scale=540:-2,format=rgb24,crop=1:1:530:700,fps=60',
 '-f','rawvideo','-pix_fmt','rgb24','pipe:1'],capture_output=True,check=True)
colors=zip(result.stdout[0::3],result.stdout[1::3],result.stdout[2::3])
for index,(r,g,b) in enumerate(colors):
 if abs(r-250)<=3 and abs(g-246)<=3 and abs(b-240)<=3 and r-g>=2 and g-b>=3:
  print(index/60)
  break
else: raise RuntimeError('No native fixture frame detected; inspect the raw recording')
PYCODE
)
ffmpeg -hide_banner -loglevel error -y -ss "$START" -i "$RAW/native.mp4" \
  -vf 'scale=540:-2,tpad=stop_mode=clone:stop_duration=6' -t 6 \
  -an -c:v libx264 -r 30 -g 30 -keyint_min 30 -crf 18 -pix_fmt yuv420p -movflags +faststart "$OUT/$NAME.mp4"
xcrun simctl io "$SIM" screenshot "$OUT/$NAME.png" >/dev/null
printf 'Captured native %s preview: %s\n' "$MODE" "$OUT/$NAME.mp4"
