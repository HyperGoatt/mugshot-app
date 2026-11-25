#!/usr/bin/env python3
"""Real disposable Git contracts for safe task preparation."""
import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    "prepare_task", Path(__file__).with_name("prepare-task.py")
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="task source fixtures ")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.remote = self.base / "remote.git"
        self.seed = self.base / "publisher"
        self.local = self.base / "everyday checkout"
        self.run_git(self.base, "init", "--bare", "--initial-branch=main", str(self.remote))
        self.run_git(self.base, "clone", str(self.remote), str(self.seed))
        self.identity(self.seed)
        self.commit(self.seed, "original")
        self.run_git(self.seed, "push", "origin", "main")
        self.run_git(self.base, "clone", str(self.remote), str(self.local))
        self.identity(self.local)

    def run_git(self, root, *args):
        environment = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        result = subprocess.run(
            ["git", "-C", str(root), *args],
            capture_output=True, text=True, env=environment, check=True,
        )
        return result.stdout.strip()

    def identity(self, root):
        self.run_git(root, "config", "user.name", "Task preparation fixture")
        self.run_git(root, "config", "user.email", "fixture@example.invalid")

    def commit(self, root, content):
        (root / "source.txt").write_text(content)
        self.run_git(root, "add", "source.txt")
        self.run_git(root, "commit", "-m", content)
        return self.run_git(root, "rev-parse", "HEAD")

    def publish(self, content):
        head = self.commit(self.seed, content)
        self.run_git(self.seed, "push", "origin", "main")
        return head

    def prepare(self, path=None):
        return MODULE.prepare(path or self.local, str(self.remote))

    def test_clean_current_main_is_unchanged(self):
        original = self.run_git(self.local, "rev-parse", "HEAD")
        result = self.prepare()
        self.assertEqual(result["commit"], original)
        self.assertTrue(result["clean"])

    def test_stale_main_fast_forwards_to_published_source(self):
        latest = self.publish("published update")
        result = self.prepare()
        self.assertEqual(result["commit"], latest)
        self.assertEqual((self.local / "source.txt").read_text(), "published update")

    def test_untracked_work_is_preserved_and_blocks_refresh(self):
        latest = self.publish("remote update")
        (self.local / "new-work.txt").write_text("keep this")
        original = self.run_git(self.local, "rev-parse", "HEAD")
        with self.assertRaisesRegex(MODULE.TaskStartError, "unsaved changes"):
            self.prepare()
        self.assertEqual(self.run_git(self.local, "rev-parse", "HEAD"), original)
        self.assertNotEqual(original, latest)
        self.assertEqual((self.local / "new-work.txt").read_text(), "keep this")

    def test_tracked_work_is_preserved_and_blocks_refresh(self):
        (self.local / "source.txt").write_text("local edits")
        with self.assertRaisesRegex(MODULE.TaskStartError, "unsaved changes"):
            self.prepare()
        self.assertEqual((self.local / "source.txt").read_text(), "local edits")

    def test_unpublished_main_commit_is_not_pushed_or_replaced(self):
        original_remote = self.run_git(self.seed, "rev-parse", "HEAD")
        local = self.commit(self.local, "unpublished")
        with self.assertRaisesRegex(MODULE.TaskStartError, "unpublished"):
            self.prepare()
        self.assertEqual(self.run_git(self.local, "rev-parse", "HEAD"), local)
        self.assertEqual(self.run_git(self.remote, "rev-parse", "main"), original_remote)

    def test_divergent_main_is_not_merged(self):
        local = self.commit(self.local, "local history")
        self.publish("different remote history")
        with self.assertRaisesRegex(MODULE.TaskStartError, "divergent"):
            self.prepare()
        self.assertEqual(self.run_git(self.local, "rev-parse", "HEAD"), local)

    def test_feature_branch_is_not_switched_or_reset(self):
        self.run_git(self.local, "switch", "-c", "codex/held-feature")
        with self.assertRaisesRegex(MODULE.TaskStartError, "feature branch"):
            self.prepare()
        self.assertEqual(
            self.run_git(self.local, "branch", "--show-current"), "codex/held-feature"
        )

    def test_wrong_repository_is_rejected_before_fetch(self):
        old_remote = self.run_git(self.local, "rev-parse", "origin/main")
        self.publish("must not fetch")
        with self.assertRaisesRegex(MODULE.TaskStartError, "Wrong source"):
            MODULE.prepare(self.local, str(self.base / "wrong.git"))
        self.assertEqual(self.run_git(self.local, "rev-parse", "origin/main"), old_remote)

    def test_subdirectory_resolves_the_primary_checkout_with_spaces(self):
        child = self.local / "nested"
        child.mkdir()
        self.assertEqual(self.prepare(child)["path"], str(self.local.resolve()))

    def test_fetch_failure_preserves_source_and_retry_succeeds(self):
        original = self.run_git(self.local, "rev-parse", "HEAD")
        moved = self.base / "temporarily unavailable.git"
        self.remote.rename(moved)
        with self.assertRaisesRegex(MODULE.TaskStartError, "fetch"):
            self.prepare()
        self.assertEqual(self.run_git(self.local, "rev-parse", "HEAD"), original)
        self.assertEqual((self.local / "source.txt").read_text(), "original")
        moved.rename(self.remote)
        self.assertEqual(self.prepare()["commit"], original)

    def test_origin_transports_share_one_github_identity(self):
        self.assertEqual(
            MODULE.normalized_origin("git@github.com:HyperGoatt/mugshot-app.git"),
            MODULE.normalized_origin("https://github.com/hypergoatt/mugshot-app"),
        )


if __name__ == "__main__":
    unittest.main()
