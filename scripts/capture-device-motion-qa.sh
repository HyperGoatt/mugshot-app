#!/bin/bash
# Record the native DEBUG authoring sequence without touching an account app.
set -euo pipefail
if [ "$#" -ne 3 ]; then echo 'Usage: capture-device-motion-qa.sh DEVICE APP_PATH OUTPUT_DIRECTORY' >&2; exit 2; fi
DEVICE="$1"
APP="$2"
OUT="$3"
mkdir -p "$OUT"
BUNDLE=$(python3 - "$APP/Info.plist" <<'PY'
import plistlib,sys
x=plistlib.load(open(sys.argv[1],'rb'))
assert x['CFBundleIdentifier'] in ['co.mugshot.app.motionqa','co.mugshot.app.testMugshotUITests']
assert x['MUGSHOT_SUPABASE_URL']=='https://publication-fixture.invalid'
assert x['MUGSHOT_SUPABASE_PUBLISHABLE_KEY']=='synthetic-key'
assert not x.get('MUGSHOT_POSTHOG_PROJECT_TOKEN')
assert x['CFBundleDisplayName']=='Mugshot Motion QA'
print(x['CFBundleIdentifier'])
PY
)
codesign --verify --deep --strict "$APP"
while IFS= read -r -d '' LIBRARY; do codesign --verify --strict "$LIBRARY"; done < <(find "$APP" -name '*.dylib' -print0)
xcrun devicectl device install app --device "$DEVICE" "$APP" > "$OUT/install.log" 2>&1
if ! xcrun devicectl device copy from --device "$DEVICE" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
  --source "Library/Preferences/$BUNDLE.plist" --destination "$OUT/before-preferences.plist" > "$OUT/before-preferences.log" 2>&1; then
  if ! rg -q 'NSCocoaErrorDomain error 260|No such file or directory' "$OUT/before-preferences.log"; then cat "$OUT/before-preferences.log" >&2; exit 1; fi
fi
ARGS=(--ui-testing --ui-testing-completion-motion-design-qa --ui-testing-motion-playback)
if [ "${MUGSHOT_QA_REDUCED:-0}" = 1 ]; then ARGS+=(--ui-testing-reduce-motion); fi
if [ "${MUGSHOT_QA_ACCESSIBLE:-0}" = 1 ]; then ARGS+=(--ui-testing-accessibility-xxxl); fi
xcrun devicectl device process launch --device "$DEVICE" --terminate-existing --json-output "$OUT/launch.json" "$BUNDLE" "${ARGS[@]}" > "$OUT/launch.log" 2>&1
if xcrun devicectl device capture screen-record --device "$DEVICE" --duration 30 --destination "$OUT/native.mp4" > "$OUT/record.log" 2>&1; then
  CAPTURE_MODE=video
else
  if ! rg -q 'com.apple.coredevice.feature.screenrecording' "$OUT/record.log"; then cat "$OUT/record.log" >&2; exit 1; fi
  CAPTURE_MODE=timed-stills
  # Device recording is optional. Native screenshots remain supported on this
  # physical iPhone; capture the actual state sequence, never synthesize motion.
  python3 - "$DEVICE" "$OUT" <<'PYTIME'
from pathlib import Path
import subprocess,sys,time
out=Path(sys.argv[2]); start=time.monotonic()
for index,offset in enumerate([0,3.8,5.7,7.7,9.7,11.7,13.7,16,20.7,24.5],1):
 time.sleep(max(0,start+offset-time.monotonic()))
 subprocess.run(['xcrun','devicectl','device','capture','screenshot','--device',sys.argv[1],
                 '--destination',str(out/f'frame-{index:02d}.png')],check=True,capture_output=True)
PYTIME
fi
xcrun devicectl device capture screenshot --device "$DEVICE" --destination "$OUT/settled.png" > "$OUT/screenshot.log" 2>&1
xcrun devicectl device copy from --device "$DEVICE" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
  --source "Library/Preferences/$BUNDLE.plist" --destination "$OUT/fixture-preferences.plist" > "$OUT/preferences.log" 2>&1
python3 - "$OUT" "$CAPTURE_MODE" <<'PY'
from pathlib import Path
import json,plistlib,sys
out=Path(sys.argv[1]); x=plistlib.loads((out/'fixture-preferences.plist').read_bytes())
assert x.get('MugshotMotionQA.playbackState')=='complete','Playback was interrupted; do not claim completion.'
operations=x.get('MugshotMotionQA.operationIDs',[])
assert len(operations)==3
before=out/'before-preferences.plist'
previous=plistlib.loads(before.read_bytes()).get('MugshotMotionQA.operationIDs',[]) if before.exists() else []
assert not set(operations).intersection(previous),'Stale completion from an earlier playback run.'
prefix='MugshotCompletionFeedback.v2.00000000-0000-4000-8000-000000000051.'
counts=[sum(1 for k,v in x.items() if k.startswith(prefix) and k.endswith(op) and v is True) for op in operations]
assert counts==[1,1,1], 'Completed operation receipt consumption differs from exactly once.'
wrong=sum(1 for k in x if k.startswith('MugshotCompletionFeedback.v2.00000000-0000-4000-8000-000000000052.'))
assert wrong==0,'Another owner consumed the fixture result.'
result={'playback':'complete','operation_count':len(operations),'consumed_once_per_operation':counts,
        'wrong_owner_consumptions':wrong,'backend':'synthetic','capture':'physical iPhone',
        'control':'native DEBUG state sequence; touch routing separately verified in Simulator',
        'capture_mode':sys.argv[2], 'fresh_operations_verified':True}
(out/'acceptance.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
PY
