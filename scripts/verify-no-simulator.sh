#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODE="${1:-fast}"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
DENO_BIN=""
EXPECTED_DENO_VERSION="2.9.3"

usage() {
  cat <<'EOF'
Usage: ./scripts/verify-no-simulator.sh [fast|backend|full-static]

  fast         Diff safety, conflict markers, product spelling, migrations
  backend      fast + optional SQL parsing + local-only Deno checks/tests
  full-static  backend + generic iOS Simulator SDK app/test compile (no boot)

This script never invokes Supabase, psql, simctl, app launch, or UI tests.
EOF
}

pass_check() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS: %s\n' "$1"
}

fail_check() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL: %s\n' "$1" >&2
}

skip_check() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  printf 'SKIP: %s — %s\n' "$1" "$2"
}

run_check() {
  local label="$1"
  shift

  printf '\n==> %s\n' "${label}"
  if "$@"; then
    pass_check "${label}"
  else
    fail_check "${label}"
  fi
}

check_unstaged_diff() {
  git diff --check --
}

check_staged_diff() {
  git diff --cached --check --
}

check_untracked_whitespace() {
  local file
  local status=0

  while IFS= read -r file; do
    case "${file}" in
      .codex/*|DerivedData/*)
        continue
        ;;
    esac
    [ -f "${file}" ] || continue
    [ ! -L "${file}" ] || continue
    if grep -Iq . "${file}"; then
      awk '
        /[ \t]+$/ {
          printf "%s:%d: trailing whitespace\n", FILENAME, FNR
          found = 1
        }
        END { exit found ? 1 : 0 }
      ' "${file}" || status=1
    fi
  done < <(git ls-files --others --exclude-standard)

  return "${status}"
}

check_conflict_markers() {
  local matches
  local status

  if command -v rg >/dev/null 2>&1; then
    matches="$(rg -n --hidden --no-messages \
      --glob '!.git/**' --glob '!.codex/**' --glob '!DerivedData/**' \
      -e '^(<<<<<<< |=======|>>>>>>> )' "${REPO_ROOT}")"
  else
    matches="$(grep -rInE \
      --exclude-dir=.git --exclude-dir=.codex --exclude-dir=DerivedData \
      '^(<<<<<<< |=======|>>>>>>> )' "${REPO_ROOT}" 2>/dev/null)"
  fi
  status=$?
  if [ "${status}" -eq 1 ]; then
    return 0
  fi
  if [ "${status}" -ne 0 ]; then
    return "${status}"
  fi

  printf '%s\n' "${matches}" >&2
  return 1
}

check_ascii_cafe_spelling() {
  local matches
  local status
  local fallback_pattern

  if command -v rg >/dev/null 2>&1; then
    matches="$(rg -nPi --hidden --no-messages \
      --glob '!.git/**' --glob '!.codex/**' --glob '!DerivedData/**' \
      -e 'caf[\x{00e9}\x{00e8}\x{00ea}\x{00eb}]' "${REPO_ROOT}")"
  else
    fallback_pattern="$(printf 'caf(\303\251|\303\250|\303\252|\303\253|\303\211|\303\210|\303\212|\303\213)')"
    matches="$(grep -rIniE \
      --exclude-dir=.git --exclude-dir=.codex --exclude-dir=DerivedData \
      "${fallback_pattern}" "${REPO_ROOT}" 2>/dev/null)"
  fi
  status=$?
  if [ "${status}" -eq 1 ]; then
    return 0
  fi
  if [ "${status}" -ne 0 ]; then
    return "${status}"
  fi

  printf '%s\n' "${matches}" >&2
  return 1
}

check_documentation() {
  "${REPO_ROOT}/scripts/check-documentation.sh"
}

check_migration_names() {
  local migration_dir="${REPO_ROOT}/supabase/migrations"
  local name
  local timestamp
  local previous_timestamp=""
  local count=0
  local invalid=0

  if [ ! -d "${migration_dir}" ]; then
    printf 'Missing migration directory: %s\n' "${migration_dir}" >&2
    return 1
  fi

  while IFS= read -r name; do
    [ -n "${name}" ] || continue
    count=$((count + 1))

    if [[ ! "${name}" =~ ^[0-9]{14}_[a-z0-9_]+\.sql$ ]]; then
      printf 'Invalid migration filename: %s\n' "${name}" >&2
      invalid=1
      continue
    fi

    timestamp="${name:0:14}"
    if [ "${timestamp}" = "${previous_timestamp}" ]; then
      printf 'Duplicate migration timestamp: %s\n' "${timestamp}" >&2
      invalid=1
    fi
    previous_timestamp="${timestamp}"
  done < <(find "${migration_dir}" -maxdepth 1 -type f -name '*.sql' -exec basename {} \; | LC_ALL=C sort)

  if [ "${count}" -eq 0 ]; then
    printf 'No SQL migrations found.\n' >&2
    return 1
  fi

  [ "${invalid}" -eq 0 ]
}

python_has_pglast() {
  python3 -c 'import pglast' >/dev/null 2>&1
}

parse_sql_with_pglast() {
  python3 - "${REPO_ROOT}" <<'PY'
from pathlib import Path
import re
import sys

from pglast import parse_sql

root = Path(sys.argv[1])
sql_roots = (
    root / "supabase" / "migrations",
    root / "supabase" / "tests",
    root / "supabase" / "manual",
    root / "supabase" / "release-data-cleanup",
)
paths = sorted(
    path
    for sql_root in sql_roots
    if sql_root.is_dir()
    for path in sql_root.glob("*.sql")
)

if not paths:
    raise SystemExit("No SQL files found")

failures: list[str] = []
for path in paths:
    source = path.read_text(encoding="utf-8")
    # psql client directives are not PostgreSQL grammar.
    source = re.sub(r"(?m)^\s*\\[^\n]*(?:\n|$)", "", source)
    try:
        parse_sql(source)
    except Exception as error:  # pglast exposes parser-version-specific errors
        failures.append(f"{path.relative_to(root)}: {error}")

if failures:
    print("\n".join(failures), file=sys.stderr)
    raise SystemExit(1)

print(f"Parsed {len(paths)} SQL files locally.")
PY
}

deno_format_check() {
  local deno_files=()
  local file

  while IFS= read -r file; do
    [ -n "${file}" ] || continue
    deno_files+=("${REPO_ROOT}/${file}")
  done < <(
    {
      git diff --name-only --diff-filter=ACMR -- supabase/functions
      git diff --cached --name-only --diff-filter=ACMR -- supabase/functions
      git ls-files --others --exclude-standard -- supabase/functions
    } | awk '/\.ts$/' | LC_ALL=C sort -u
  )

  if [ "${#deno_files[@]}" -eq 0 ]; then
    printf 'No changed Deno TypeScript files to format-check.\n'
    return 0
  fi

  DENO_NO_UPDATE_CHECK=1 "${DENO_BIN}" fmt --check "${deno_files[@]}"
}

deno_type_check() {
  local function_dir
  local local_files=()
  local dependency_args=()
  local file
  local status=0

  for function_dir in "${REPO_ROOT}"/supabase/functions/*; do
    [ -d "${function_dir}" ] || continue
    local_files=()
    while IFS= read -r file; do
      local_files+=("$(basename "${file}")")
    done < <(find "${function_dir}" -maxdepth 1 -type f -name '*.ts' | LC_ALL=C sort)

    [ "${#local_files[@]}" -gt 0 ] || continue
    printf '%s\n' "Checking $(basename "${function_dir}")"
    (
      cd "${function_dir}" || exit 1
      if [ -f deno.lock ]; then
        dependency_args=(--frozen --lock=deno.lock)
      else
        dependency_args=(--no-lock)
      fi
      DENO_NO_UPDATE_CHECK=1 "${DENO_BIN}" test \
        --no-run --cached-only --no-remote \
        "${dependency_args[@]}" "${local_files[@]}"
    ) || status=1
  done

  return "${status}"
}

deno_test_check() {
  local function_dir
  local test_files=()
  local dependency_args=()
  local file
  local test_count=0
  local status=0

  for function_dir in "${REPO_ROOT}"/supabase/functions/*; do
    [ -d "${function_dir}" ] || continue
    test_files=()
    while IFS= read -r file; do
      test_files+=("$(basename "${file}")")
    done < <(find "${function_dir}" -maxdepth 1 -type f -name '*_test.ts' | LC_ALL=C sort)

    [ "${#test_files[@]}" -gt 0 ] || continue
    test_count=$((test_count + ${#test_files[@]}))
    printf '%s\n' "Testing $(basename "${function_dir}")"
    (
      cd "${function_dir}" || exit 1
      if [ -f deno.lock ]; then
        dependency_args=(--frozen --lock=deno.lock)
      else
        dependency_args=(--no-lock)
      fi
      DENO_NO_UPDATE_CHECK=1 "${DENO_BIN}" test \
        --cached-only "${dependency_args[@]}" "${test_files[@]}"
    ) || status=1
  done

  if [ "${test_count}" -eq 0 ]; then
    printf 'No Deno test files found.\n' >&2
    return 1
  fi

  return "${status}"
}

hermetic_postgres_contracts() {
  npm test --silent --prefix "${REPO_ROOT}/qa/pglite"
}

resolve_deno_bin() {
  local repository_deno="${REPO_ROOT}/qa/pglite/node_modules/.bin/deno"
  local candidate=""
  local version=""

  if [ -x "${repository_deno}" ]; then
    candidate="${repository_deno}"
  elif command -v deno >/dev/null 2>&1; then
    candidate="$(command -v deno)"
  fi

  [ -n "${candidate}" ] || return 1
  version="$("${candidate}" --version 2>/dev/null | awk 'NR == 1 { print $2 }')"
  [ "${version}" = "${EXPECTED_DENO_VERSION}" ] || return 1
  printf '%s\n' "${candidate}"
}

compile_for_testing_without_simulator() {
  local temporary_root="${TMPDIR:-/tmp}"
  local derived_data_path

  if [ -z "${temporary_root}" ] || [ "${temporary_root}" = "/" ]; then
    temporary_root="/tmp"
  fi
  derived_data_path="${temporary_root%/}/mugshot-no-simulator-derived-data"

  xcodebuild \
    -project "${REPO_ROOT}/testMugshot.xcodeproj" \
    -scheme testMugshot \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "${derived_data_path}" \
    -quiet \
    -hideShellScriptEnvironment \
    -disableAutomaticPackageResolution \
    -onlyUsePackageVersionsFromResolvedFile \
    -skipPackageUpdates \
    CODE_SIGNING_ALLOWED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO \
    build-for-testing
}

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

case "${MODE}" in
  fast|backend|full-static)
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if ! git -C "${REPO_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || [ ! -f "${REPO_ROOT}/testMugshot.xcodeproj/project.pbxproj" ]; then
  printf 'Run this script from a complete MugShot repository checkout.\n' >&2
  exit 2
fi

cd "${REPO_ROOT}" || exit 2

printf 'MugShot no-Simulator verification\n'
printf 'Mode: %s\n' "${MODE}"
printf 'Repository: %s\n' "${REPO_ROOT}"
printf 'Safety: no Supabase connection, Simulator boot, app launch, or UI tests\n'

run_check "Unstaged diff integrity" check_unstaged_diff
run_check "Staged diff integrity" check_staged_diff
run_check "Untracked text whitespace" check_untracked_whitespace
run_check "No unresolved conflict markers" check_conflict_markers
run_check "ASCII cafe spelling" check_ascii_cafe_spelling
run_check "Living documentation integrity" check_documentation
run_check "Migration filename and timestamp integrity" check_migration_names

if [ "${MODE}" = "backend" ] || [ "${MODE}" = "full-static" ]; then
  if ! command -v python3 >/dev/null 2>&1; then
    skip_check "PostgreSQL syntax parsing" "python3 is not installed"
  elif ! python_has_pglast; then
    skip_check "PostgreSQL syntax parsing" "the optional local Python pglast package is not installed"
  else
    run_check "PostgreSQL syntax parsing" parse_sql_with_pglast
  fi

  if ! DENO_BIN="$(resolve_deno_bin)"; then
    fail_check \
      "Deno checks require pinned ${EXPECTED_DENO_VERSION}; run npm ci --prefix qa/pglite --ignore-scripts"
  else
    run_check "Changed Deno formatting" deno_format_check
    run_check "Deno offline type checking" deno_type_check
    run_check "Deno cached-only unit tests" deno_test_check
  fi

  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    fail_check "Hermetic PostgreSQL behavior contracts — Node.js and npm are required"
  elif [ ! -d "${REPO_ROOT}/qa/pglite/node_modules/@electric-sql/pglite" ]; then
    fail_check \
      "Hermetic PostgreSQL behavior contracts — run npm ci --prefix qa/pglite --ignore-scripts"
  else
    run_check "Hermetic PostgreSQL behavior contracts" hermetic_postgres_contracts
  fi
fi

if [ "${MODE}" = "full-static" ]; then
  if ! command -v xcodebuild >/dev/null 2>&1; then
    fail_check "Generic iOS Debug app/test compile — xcodebuild is required"
  else
    run_check \
      "Generic iOS Debug app/test compile without Simulator boot" \
      compile_for_testing_without_simulator
  fi
fi

printf '\nSummary: %d passed, %d failed, %d skipped\n' \
  "${PASS_COUNT}" "${FAIL_COUNT}" "${SKIP_COUNT}"

if [ "${FAIL_COUNT}" -ne 0 ]; then
  exit 1
fi

exit 0
