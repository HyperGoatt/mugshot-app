#!/usr/bin/env python3
"""Sign only an isolated synthetic QA app using an existing local device profile.

Does not provision an identity, install, archive, export, upload, or read a private
key. codesign uses the matching existing identity through the macOS keychain.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('app', type=Path)
parser.add_argument('--profile', required=True, type=Path)
parser.add_argument('--device-udid', required=True)
args = parser.parse_args()
app = args.app.resolve()
info = plistlib.loads((app / 'Info.plist').read_bytes())
bundle = info.get('CFBundleIdentifier')
if bundle not in ['co.mugshot.app.motionqa', 'co.mugshot.app.testMugshotUITests']:
    raise SystemExit('Refusing to sign an account-bearing Mugshot identity.')
if (info.get('MUGSHOT_SUPABASE_URL') != 'https://publication-fixture.invalid'
        or info.get('MUGSHOT_SUPABASE_PUBLISHABLE_KEY') != 'synthetic-key'
        or info.get('MUGSHOT_POSTHOG_PROJECT_TOKEN')
        or info.get('CFBundleDisplayName') != 'Mugshot Motion QA'
        or info.get('CFBundleURLTypes') or (app / 'PlugIns').exists()):
    raise SystemExit('QA backend, analytics, name, routing or extension isolation failed.')
profile = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(args.profile)]))
team = 'R389G6U968'
application = team + '.' + bundle
expiry = profile['ExpirationDate'].replace(tzinfo=timezone.utc)
if (profile['Entitlements'].get('application-identifier') != application
        or not profile['Entitlements'].get('get-task-allow')
        or args.device_udid not in profile.get('ProvisionedDevices', [])
        or expiry <= datetime.now(timezone.utc)):
    raise SystemExit('Profile must be current, development-only, and authorize this exact QA identity/device.')
identities = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning'], text=True)
available = set(re.findall(r'\b[0-9A-F]{40}\b', identities))
matching = [hashlib.sha1(c).hexdigest().upper() for c in profile['DeveloperCertificates']
            if hashlib.sha1(c).hexdigest().upper() in available]
if not matching:
    raise SystemExit('No matching local developer signing identity is available.')
identity = matching[0]
entitlements = {
    'application-identifier': application,
    'com.apple.developer.team-identifier': team,
    'get-task-allow': True,
    'keychain-access-groups': [application],
}
shutil.copyfile(args.profile, app / 'embedded.mobileprovision')
with tempfile.TemporaryDirectory(prefix='mugshot-motionqa-sign-') as directory:
    path = Path(directory) / 'entitlements.plist'
    path.write_bytes(plistlib.dumps(entitlements))
    frameworks = app / 'Frameworks'
    if frameworks.exists():
        nested = sorted([*frameworks.rglob('*.framework'), *frameworks.rglob('*.dylib')],
                        key=lambda p: len(p.parts), reverse=True)
        for item in nested:
            subprocess.run(['codesign', '--force', '--sign', identity, '--timestamp=none', str(item)], check=True)
    subprocess.run(['codesign', '--force', '--sign', identity, '--timestamp=none',
                    '--entitlements', str(path), '--generate-entitlement-der', str(app)], check=True)
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
actual = plistlib.loads(subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(app)], stderr=subprocess.DEVNULL))
if actual != entitlements:
    raise SystemExit('Signed capabilities differ from the restricted QA entitlement set.')
receipt = {
    'bundle_identifier': bundle,
    'display_name': info['CFBundleDisplayName'],
    'version': info['CFBundleShortVersionString'],
    'build': info['CFBundleVersion'],
    'profile_name': profile['Name'],
    'profile_expires': expiry.isoformat(),
    'signing_identity_sha1': identity,
    'entitlements': actual,
    'binary_sha256': hashlib.sha256((app / info['CFBundleExecutable']).read_bytes()).hexdigest(),
    'fixture_backend_verified': True,
    'production_analytics_disabled': True,
    'signature_verified': True,
}
(app.parent / 'motion-qa-signature.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2))
