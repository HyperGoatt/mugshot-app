#!/usr/bin/env python3
"""Prepare an isolated, fixture-only physical QA worktree; never install an app.

The app's interactive SwiftUI source stays intact. The QA identity, capabilities,
URL routing, embedded extensions and shared-import defaults are isolated so tests
cannot overwrite either installed Mugshot account container.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('worktree', type=Path)
parser.add_argument('--bundle-id', choices=['co.mugshot.app.motionqa', 'co.mugshot.app.testMugshotUITests'], default='co.mugshot.app.motionqa')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
qa = args.worktree.resolve()
if qa == root:
    raise SystemExit('Refusing to modify the active project; use a detached worktree.')

def git(path, *arguments):
    return subprocess.check_output(['git', '-C', str(path), *arguments], text=True).strip()

def common_directory(path):
    value = Path(git(path, 'rev-parse', '--git-common-dir'))
    return (value if value.is_absolute() else path / value).resolve()

if common_directory(root) != common_directory(qa):
    raise SystemExit('QA checkout must be a worktree of this repository.')
if subprocess.run(['git', '-C', str(qa), 'symbolic-ref', '-q', 'HEAD'], capture_output=True).returncode == 0:
    raise SystemExit('QA checkout must be detached from a working branch.')
if git(qa, 'status', '--porcelain'):
    raise SystemExit('QA checkout must be clean before preparation.')
base = git(qa, 'rev-parse', 'HEAD')
project = qa / 'testMugshot.xcodeproj/project.pbxproj'
text = project.read_text()
start = text.index('\t\t40E276802EC7997A005528D1 /* testMugshot */ = {')
end = text.index('\n\t\t40E2768D2EC7997C005528D1 /* testMugshotTests */ = {', start)
main = text[start:end]
for line in [
    '\t\t\t\t71B600092F00000000000009 /* Embed App Extensions */,\n',
    '\t\t\t\t71B6000A2F0000000000000A /* PBXTargetDependency */,\n',
    '\t\t\t\t73D7000A2F0000000000000A /* PBXTargetDependency */,\n',
]:
    if main.count(line) != 1:
        raise SystemExit('Project structure changed; review QA isolation before building.')
    main = main.replace(line, '')
text = text[:start] + main + text[end:]
lines = []
for line in text.splitlines():
    if any(f'"{key}[sdk=iphoneos*]"' in line for key in ['EXECUTABLE_NAME', 'PRODUCT_NAME', 'CODE_SIGN_STYLE', 'PROVISIONING_PROFILE_SPECIFIER']):
        continue
    if 'PRODUCT_BUNDLE_IDENTIFIER' in line:
        key, old = line.rsplit(' = ', 1)
        value = old.strip().rstrip(';').strip('"')
        if not value.startswith('co.mugshot.app'):
            raise SystemExit('Unexpected bundle identifier in QA project.')
        suffix = value.removeprefix('co.mugshot.app').removeprefix('.dev')
        line = key + '= ' + args.bundle_id + suffix + ';'
    if 'CODE_SIGN_ENTITLEMENTS' in line:
        line = line.rsplit(' = ', 1)[0] + '= Config/DeviceMotionQA.entitlements;'
    lines.append(line)
project.write_text('\n'.join(lines) + '\n')
with (qa / 'Config/DeviceMotionQA.entitlements').open('wb') as stream:
    plistlib.dump({'keychain-access-groups': ['R389G6U968.' + args.bundle_id]}, stream)
info_path = qa / 'Config/Info.plist'
with info_path.open('rb') as stream:
    info = plistlib.load(stream)
info['CFBundleDisplayName'] = 'Mugshot Motion QA'
info.pop('CFBundleURLTypes', None)
with info_path.open('wb') as stream:
    plistlib.dump(info, stream, sort_keys=False)
# Explicitly avoid the existing apps' shared import preferences in this fixture.
imports = qa / 'testMugshot/Models/PendingPlaceImport.swift'
source = imports.read_text()
old = 'defaults: UserDefaults(suiteName: MugshotAppGroup.identifier) ?? .standard'
if source.count(old) != 1:
    raise SystemExit('Shared import initialization changed; review isolation.')
imports.write_text(source.replace(old, 'defaults: .standard // Isolated physical QA fixture only.'))
manifest = {
    'base_commit': base,
    'bundle_identifier': args.bundle_id,
    'keychain_access_group': 'R389G6U968.' + args.bundle_id,
    'display_name': 'Mugshot Motion QA',
    'backend': 'https://publication-fixture.invalid',
    'production_analytics': False,
    'apple_capabilities': [],
    'embedded_extensions': False,
    'registered_url_schemes': [],
    'shared_import_defaults': 'QA app standard defaults only',
    'excluded_acceptance': ['production authentication', 'APNs', 'widgets', 'share extension', 'app groups'],
}
(qa / 'Config/DeviceMotionQA.json').write_text(json.dumps(manifest, indent=2) + '\n')
patch = subprocess.check_output(['git', '-C', str(qa), 'diff', '--binary'])
manifest['tracked_patch_sha256'] = hashlib.sha256(patch).hexdigest()
(qa / 'Config/DeviceMotionQA.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(manifest, indent=2))
