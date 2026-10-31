#!/usr/bin/env python3
"""Capture actual native prototype states. Only an isolated Simulator app is allowed."""
from pathlib import Path
import argparse,json,plistlib,subprocess,time,uuid
from PIL import Image

parser=argparse.ArgumentParser()
parser.add_argument('app',type=Path)
parser.add_argument('--simulator',required=True)
parser.add_argument('--only',nargs='+')
args=parser.parse_args()
root=Path(__file__).resolve().parent
info=plistlib.loads((args.app/'Info.plist').read_bytes())
bundle='co.mugshot.app.testMugshotUITests'
assert info['CFBundleIdentifier']==bundle
assert info['CFBundleSupportedPlatforms']==['iPhoneSimulator']
assert info['MUGSHOT_SUPABASE_URL']=='https://publication-fixture.invalid'
assert info['MUGSHOT_SUPABASE_PUBLISHABLE_KEY']=='synthetic-key'
assert not info.get('MUGSHOT_POSTHOG_PROJECT_TOKEN')
def run(*commands):
    return subprocess.check_output(['xcrun','simctl',*commands],text=True).strip()
run('install',args.simulator,str(args.app))
container=Path(run('get_app_container',args.simulator,bundle,'data'))
prefs=container/f'Library/Preferences/{bundle}.plist'
scenes=['journal','invitation','cover','moments','highlight','highlight-caption','places','usual','ending','share','single','quiet','quiet-large','no-photo']
selected=args.only or scenes
assert set(selected)<=set(scenes)
raw=root/'.raw';raw.mkdir(exist_ok=True)
(root/'screens').mkdir(exist_ok=True)
results=[]
for scene in selected:
    subprocess.run(['xcrun','simctl','terminate',args.simulator,bundle],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    target='highlight' if scene=='highlight-caption' else 'quiet' if scene=='quiet-large' else scene
    token='--recap-run='+str(uuid.uuid4())
    flags=['--ui-testing','--ui-testing-completion-motion-design-qa',f'--recap-scene={target}',token]
    if scene=='highlight-caption':flags+=['--recap-flipped']
    if scene=='quiet-large':flags+=['--ui-testing-reduce-motion','--ui-testing-accessibility-xxxl']
    run('launch',args.simulator,bundle,*flags)
    deadline=time.monotonic()+20
    expected=f'{target}|{token}'
    while True:
        try: ready=plistlib.loads(prefs.read_bytes()).get('WeeklyPourPreview.ready')==expected
        except (FileNotFoundError,plistlib.InvalidFileException):ready=False
        if ready:break
        if time.monotonic()>=deadline:raise RuntimeError('Native state not ready: '+scene)
        time.sleep(.15)
    path=raw/f'{scene}.png'
    run('io',args.simulator,'screenshot',str(path))
    im=Image.open(path)
    assert im.size==(1206,2622),'This capture crop is verified for the 402x874 iPhone 17 Pro only.'
    # Remove only the system status area (62 pt) and home indicator (34 pt).
    im.crop((0,186,1206,2520)).save(root/'screens'/f'{scene}.png',optimize=True)
    results.append({'scene':scene,'native_ready':True,'capture':'Simulator screenshot','crop_top_points':62,'crop_bottom_points':34})
    print('Captured '+scene,flush=True)
previous=json.loads((root/'capture-evidence.json').read_text()) if (root/'capture-evidence.json').exists() else []
merged={r['scene']:r for r in previous};merged.update({r['scene']:r for r in results})
(root/'capture-evidence.json').write_text(json.dumps(list(merged.values()),indent=2)+'\n')
