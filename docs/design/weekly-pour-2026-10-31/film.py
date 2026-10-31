#!/usr/bin/env python3
"""Record the native authoring playback, with no account app or backend mutation."""
from pathlib import Path
import argparse,json,plistlib,signal,subprocess,time,uuid
p=argparse.ArgumentParser();p.add_argument('app',type=Path);p.add_argument('--simulator',required=True);args=p.parse_args()
root=Path(__file__).resolve().parent;raw=root/'.raw';raw.mkdir(exist_ok=True)
x=plistlib.loads((args.app/'Info.plist').read_bytes());bundle='co.mugshot.app.testMugshotUITests'
assert x['CFBundleIdentifier']==bundle and x['CFBundleSupportedPlatforms']==['iPhoneSimulator']
assert x['MUGSHOT_SUPABASE_URL']=='https://publication-fixture.invalid' and x['MUGSHOT_SUPABASE_PUBLISHABLE_KEY']=='synthetic-key' and not x.get('MUGSHOT_POSTHOG_PROJECT_TOKEN')
def run(*a):return subprocess.check_output(['xcrun','simctl',*a],text=True).strip()
run('install',args.simulator,str(args.app));subprocess.run(['xcrun','simctl','terminate',args.simulator,bundle],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
container=Path(run('get_app_container',args.simulator,bundle,'data'));prefs=container/f'Library/Preferences/{bundle}.plist'
token='--recap-run='+str(uuid.uuid4())
with (raw/'record.log').open('w') as log:
 recorder=subprocess.Popen(['xcrun','simctl','io',args.simulator,'recordVideo','--codec=h264','--force',str(raw/'native-motion.mp4')],stdout=log,stderr=subprocess.STDOUT)
 try:
  time.sleep(.3)
  run('launch',args.simulator,bundle,'--ui-testing','--ui-testing-completion-motion-design-qa','--recap-scene=invitation','--recap-film',token)
  time.sleep(43)
 finally:
  recorder.send_signal(signal.SIGINT);recorder.wait(timeout=20)
assert recorder.returncode==0
metadata=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=width,height','-of','json',str(raw/'native-motion.mp4')]))
assert metadata['streams'][0]['width']==1206 and metadata['streams'][0]['height']==2622
# Find the actual first invitation frame. CFPreferences can coalesce short-lived
# readiness writes, so visual film acceptance verifies native frames instead.
from PIL import Image,ImageChops,ImageStat
size=(60,116)
frames=subprocess.check_output(['ffmpeg','-v','error','-i',str(raw/'native-motion.mp4'),'-vf','crop=1206:2334:0:186,scale=60:116:flags=bilinear,fps=10','-f','rawvideo','-pix_fmt','rgb24','pipe:1'])
names=['invitation','journal','cover','moments','highlight','highlight-caption','places','usual','ending','share','quiet','single','no-photo']
refs={name:Image.open(root/'screens'/f'{name}.png').convert('RGB').resize(size,Image.Resampling.BILINEAR) for name in names}
stride=size[0]*size[1]*3;best={name:(999,None) for name in names};first=None
for index,offset in enumerate(range(0,len(frames)-stride+1,stride)):
 im=Image.frombytes('RGB',size,frames[offset:offset+stride])
 errors={name:sum(ImageStat.Stat(ImageChops.difference(im,ref)).mean)/3 for name,ref in refs.items()}
 name=min(errors,key=errors.get)
 if errors[name]<best[name][0]:best[name]=(errors[name],index/10)
 if name=='invitation' and errors[name]<6 and first is None:first=index/10
assert first is not None,'No actual native invitation frame; inspect recording.'
missing=[name for name,(error,_) in best.items() if error>=8]
assert not missing,'Native chapters missing or interrupted: '+','.join(missing)
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(raw/'native-motion.mp4'),'-vf',f'trim=start={first},setpts=PTS-STARTPTS,fps=30,crop=1206:2334:0:186,scale=604:1168','-an','-c:v','libx264','-crf','19','-r','30','-pix_fmt','yuv420p','-movflags','+faststart',str(root/'motion.mp4')],check=True)
# Verify the encoded deliverable too: variable-frame Simulator timestamps must
# not make an apparently complete source lose a chapter after trimming.
encoded=subprocess.check_output(['ffmpeg','-v','error','-i',str(root/'motion.mp4'),'-vf','scale=60:116:flags=bilinear,fps=10','-f','rawvideo','-pix_fmt','rgb24','pipe:1'])
encoded_best={name:(999,None) for name in names}
for index,offset in enumerate(range(0,len(encoded)-stride+1,stride)):
 im=Image.frombytes('RGB',size,encoded[offset:offset+stride])
 errors={name:sum(ImageStat.Stat(ImageChops.difference(im,ref)).mean)/3 for name,ref in refs.items()}
 name=min(errors,key=errors.get)
 if errors[name]<encoded_best[name][0]:encoded_best[name]=(errors[name],index/10)
assert all(error<8 for error,_ in encoded_best.values()),'Encoded native chapters missing; inspect deliverable.'
(root/'film-evidence.json').write_text(json.dumps({'capture':'actual native Simulator authoring playback','trim_start_seconds':first,'all_required_scenes_present':True,'exported_video_verified':True,'timestamp_handling':'filter trim, reset timestamps, 30 fps; no input seek','output_scene_frame_matches':{name:{'mean_color_error':round(error,3),'seconds':at} for name,(error,at) in encoded_best.items()},'scene_frame_matches':{name:{'mean_color_error':round(error,3),'raw_seconds':at} for name,(error,at) in best.items()},'automatic_advance':'authoring film only; manual story remains self-paced'},indent=2)+'\n')
print('Native motion preview saved: '+str(root/'motion.mp4'))
