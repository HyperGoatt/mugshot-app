"""Package-boundary regression for the physical QA signing workflow."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('motion_qa_signer', Path(__file__).parents[1] / 'sign-device-motion-qa.py')
signer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signer)

class DeviceMotionSigningTests(unittest.TestCase):
    def test_root_debug_libraries_and_framework_code_are_all_signed(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / 'Fixture.app'
            framework = app / 'Frameworks' / 'Crash.framework'
            framework.mkdir(parents=True)
            root_debug = app / 'Fixture.debug.dylib'
            preview = app / '__preview.dylib'
            swift_runtime = app / 'Frameworks' / 'libswiftCore.dylib'
            for path in [root_debug, preview, swift_runtime, app / 'Info.plist']:
                path.touch()
            self.assertEqual(set(signer.nested_code_to_sign(app)), {root_debug, preview, swift_runtime, framework})

    def test_child_framework_is_signed_before_its_parent(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / 'Fixture.app'
            parent = app / 'Frameworks' / 'Outer.framework'
            child = parent / 'Frameworks' / 'Inner.framework'
            child.mkdir(parents=True)
            result = signer.nested_code_to_sign(app)
            self.assertLess(result.index(child), result.index(parent))

if __name__ == '__main__':
    unittest.main()
