#!/usr/bin/env python3
"""Refresh the authoritative main checkout without discarding local work."""
import argparse
import json
import os
import subprocess
from pathlib import Path


class TaskStartError(RuntimeError):
    """The current checkout cannot safely become a fresh task baseline."""


def git(root, *args):
    environment = dict(os.environ, GIT_TERMINAL_PROMPT="0")
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        capture_output=True,
        text=True,
        env=environment,
        timeout=60,
    )
    if result.returncode:
        raise TaskStartError("Git operation failed: " + args[0])
    return result.stdout.strip()


def normalized_origin(value):
    value = value.rstrip("/")
    if value.startswith("git@github.com:"):
        value = "https://github.com/" + value.split(":", 1)[1]
    elif value.startswith("ssh://git@github.com/"):
        value = "https://github.com/" + value.split("github.com/", 1)[1]
    if value.endswith(".git"):
        value = value[:-4]
    return value.casefold() if value.startswith("https://github.com/") else value


def primary_checkout(workspace):
    records = git(workspace, "worktree", "list", "--porcelain", "-z").split("\0")
    if not records or not records[0].startswith("worktree "):
        raise TaskStartError("Cannot identify the primary checkout.")
    return Path(records[0][len("worktree "):])


def require_clean_main(root):
    if git(root, "symbolic-ref", "--short", "HEAD") != "main":
        raise TaskStartError("The primary checkout is on a feature branch; it was preserved.")
    if git(root, "status", "--porcelain=v1", "--untracked-files=normal"):
        raise TaskStartError("The primary checkout has unsaved changes; they were preserved.")


def prepare(workspace, expected_origin):
    root = primary_checkout(workspace)
    actual_origin = git(root, "config", "--get", "remote.origin.url")
    if normalized_origin(actual_origin) != normalized_origin(expected_origin):
        raise TaskStartError("Wrong source repository; no fetch or update was performed.")
    require_clean_main(root)
    original_head = git(root, "rev-parse", "HEAD")
    git(root, "fetch", "--prune", "origin")
    require_clean_main(root)
    if git(root, "rev-parse", "HEAD") != original_head:
        raise TaskStartError("The primary checkout changed during the refresh; retry safely.")
    remote_head = git(root, "rev-parse", "--verify", "refs/remotes/origin/main^{commit}")
    unpublished = int(git(root, "rev-list", "--count", remote_head + "..HEAD"))
    if unpublished:
        raise TaskStartError("Local main has unpublished or divergent commits; no merge was attempted.")
    git(root, "merge", "--ff-only", remote_head)
    require_clean_main(root)
    if git(root, "rev-parse", "HEAD") != remote_head:
        raise TaskStartError("The checkout changed while updating; no task baseline was issued.")
    return {
        "path": str(root),
        "branch": "main",
        "commit": remote_head,
        "clean": True,
        "synchronized": True,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", choices=("app", "marketing", "both"), default="app")
    arguments = parser.parse_args()
    workspace = Path(__file__).resolve().parent.parent
    try:
        app_root = primary_checkout(workspace)
        targets = {
            "app": (workspace, "https://github.com/HyperGoatt/mugshot-app.git"),
            "marketing": (
                app_root.parent / "mugshot-marketing",
                "https://github.com/HyperGoatt/mugshot-marketing.git",
            ),
        }
        selected = targets if arguments.repository == "both" else {
            arguments.repository: targets[arguments.repository]
        }
        results = {}
        for name, (path, origin) in selected.items():
            results[name] = prepare(path, origin)
        print(json.dumps(results, indent=2))
        return 0
    except (TaskStartError, subprocess.TimeoutExpired, OSError) as error:
        parser.exit(1, "Task preparation stopped: " + str(error) + "\n")


if __name__ == "__main__":
    raise SystemExit(main())
