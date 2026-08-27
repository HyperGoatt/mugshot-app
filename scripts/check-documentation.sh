#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

LIVING_DOCS=(
  docs/README.md
  docs/CURRENT_PRODUCT_STATUS.md
  docs/FEATURE_STATUS_MATRIX.md
  docs/REAL_DATA_FLOW_STATUS.md
  docs/REPO_MAP.md
  docs/PRODUCT_ROADMAP.md
  docs/NOTIFICATION_SYSTEM.md
  docs/CURRENT_SPRINT.md
  docs/TESTFLIGHT_FEEDBACK_LEDGER.md
  docs/POST_REACTION_CONTRACT.md
  docs/MUGSY_ASSET_STATUS.md
  docs/SUPABASE_RELEASE_WORKFLOW.md
  docs/VERIFICATION_POLICY.md
  docs/POSTHOG_ANALYTICS_PLAN.md
  docs/TESTFLIGHT_UPLOAD_HANDOFF.md
  docs/DOCUMENTATION_POLICY.md
  docs/CHANGELOG.md
)

status=0

fail() {
  printf 'Documentation check failed: %s\n' "$1" >&2
  status=1
}

for document in "${LIVING_DOCS[@]}"; do
  path="${REPO_ROOT}/${document}"
  if [ ! -f "${path}" ]; then
    fail "missing living document ${document}"
    continue
  fi
  grep -q '^document_type: living$' "${path}" || fail "${document} is not marked living"
  grep -q '^status: current$' "${path}" || fail "${document} is not marked current"
  grep -Eq '^last_verified: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "${path}" \
    || fail "${document} has no ISO last_verified date"
done

if command -v rg >/dev/null 2>&1; then
  stale_pattern='Notifications have no active native surface|No notification center or push|Notifications \| Blocked|Notification rebuild.*Not yet|Friends and notifications are absent in iOS|device registration and notification function calls remain unwired'
  for document in "${LIVING_DOCS[@]}"; do
    if rg -n -i "${stale_pattern}" "${REPO_ROOT}/${document}"; then
      fail "${document} contains a superseded current-state claim"
    fi
  done
fi

python3 - "${REPO_ROOT}" "${LIVING_DOCS[@]}" <<'PY' || status=1
from pathlib import Path
from urllib.parse import unquote
import re
import sys

root = Path(sys.argv[1])
documents = [root / value for value in sys.argv[2:]]
pattern = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
failures: list[str] = []

for document in documents:
    source = document.read_text(encoding="utf-8")
    for raw_target in pattern.findall(source):
        target = raw_target.strip().strip("<>")
        if target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        target = unquote(target.split("#", 1)[0])
        if not target:
            continue
        resolved = (document.parent / target).resolve()
        if not resolved.exists():
            failures.append(f"{document.relative_to(root)}: missing local link {raw_target}")

if failures:
    print("\n".join(failures), file=sys.stderr)
    raise SystemExit(1)
PY

base_ref=""
if git -C "${REPO_ROOT}" show-ref --verify --quiet refs/remotes/origin/main; then
  base_ref="$(git -C "${REPO_ROOT}" merge-base origin/main HEAD)"
elif git -C "${REPO_ROOT}" rev-parse --verify HEAD~1 >/dev/null 2>&1; then
  base_ref="HEAD~1"
fi

changed_files="$({
  if [ -n "${base_ref}" ]; then
    git -C "${REPO_ROOT}" diff --name-only "${base_ref}"...HEAD
  fi
  git -C "${REPO_ROOT}" diff --name-only
  git -C "${REPO_ROOT}" diff --cached --name-only
  git -C "${REPO_ROOT}" ls-files --others --exclude-standard
} | LC_ALL=C sort -u)"

if printf '%s\n' "${changed_files}" | grep -Eq '^(testMugshot/|testMugshotTests/|testMugshotUITests/|testMugshot\.xcodeproj/|supabase/|Config/)'; then
  printf '%s\n' "${changed_files}" | grep -qx 'docs/CHANGELOG.md' \
    || fail "product/backend/build changes require docs/CHANGELOG.md"
  if ! printf '%s\n' "${changed_files}" | grep -Eq '^docs/(CURRENT_PRODUCT_STATUS|FEATURE_STATUS_MATRIX|REAL_DATA_FLOW_STATUS|REPO_MAP|PRODUCT_ROADMAP|NOTIFICATION_SYSTEM|SUPABASE_RELEASE_WORKFLOW|POSTHOG_ANALYTICS_PLAN|TESTFLIGHT_UPLOAD_HANDOFF)\.md$'; then
    fail "product/backend/build changes require an affected living document"
  fi
fi

if [ "${status}" -ne 0 ]; then
  exit "${status}"
fi

printf 'Documentation manifest, metadata, links, stale claims, and change impact passed.\n'
