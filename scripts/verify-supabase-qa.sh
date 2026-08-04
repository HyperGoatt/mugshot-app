#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
QA_BRANCH_ID="${1:-${MUGSHOT_QA_BRANCH_ID:-}}"
PRODUCTION_REF="${MUGSHOT_PRODUCTION_PROJECT_REF:-quskamnfwglctqewwfln}"
SUPABASE_CLI_VERSION="2.109.1"

if [ -z "${QA_BRANCH_ID}" ]; then
  printf 'Usage: %s <Supabase QA branch ID>\n' "${0}" >&2
  exit 2
fi

if [ "$#" -gt 0 ]; then
  shift
fi

for dependency in node npm npx jq; do
  if ! command -v "${dependency}" >/dev/null 2>&1; then
    printf 'Missing required dependency: %s\n' "${dependency}" >&2
    exit 2
  fi
done

if [ ! -d "${REPO_ROOT}/qa/pglite/node_modules/pg" ]; then
  printf 'Install pinned QA dependencies with npm ci --prefix qa/pglite.\n' >&2
  exit 2
fi

branch_json="$(npx --yes "supabase@${SUPABASE_CLI_VERSION}" branches get "${QA_BRANCH_ID}" --output json)"
qa_database_url="$(jq -r '.POSTGRES_URL_NON_POOLING // empty' <<<"${branch_json}")"

if [ -z "${qa_database_url}" ]; then
  printf 'The selected QA branch has no direct database URL.\n' >&2
  exit 1
fi
if [[ "${qa_database_url}" == *"db.${PRODUCTION_REF}.supabase.co"* ]]; then
  printf 'Refusing to seed or test the MugShot production project.\n' >&2
  exit 1
fi

printf 'Checking local and QA migration alignment...\n'
migration_table="$(npx --yes "supabase@${SUPABASE_CLI_VERSION}" migration list --db-url "${qa_database_url}")"
if jq -e '.migrations | type == "array"' >/dev/null 2>&1 <<<"${migration_table}"; then
  local_only_count="$(
    jq '[.migrations[] | select(.local != "" and .remote == "")] | length' \
      <<<"${migration_table}"
  )"
  remote_only_count="$(
    jq '[.migrations[] | select(.local == "" and .remote != "")] | length' \
      <<<"${migration_table}"
  )"
else
  local_only_count="$(awk -F '|' '
    /[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/ {
      local_version = $1
      remote_version = $2
      gsub(/[^0-9]/, "", local_version)
      gsub(/[^0-9]/, "", remote_version)
      if (local_version != "" && remote_version == "") count += 1
    }
    END { print count + 0 }
  ' <<<"${migration_table}")"
  remote_only_count="$(awk -F '|' '
    /[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/ {
      local_version = $1
      remote_version = $2
      gsub(/[^0-9]/, "", local_version)
      gsub(/[^0-9]/, "", remote_version)
      if (local_version == "" && remote_version != "") count += 1
    }
    END { print count + 0 }
  ' <<<"${migration_table}")"
fi

if [ "${local_only_count}" -ne 0 ] || [ "${remote_only_count}" -ne 0 ]; then
  printf 'Migration drift detected: %s local-only, %s remote-only.\n' "${local_only_count}" "${remote_only_count}" >&2
  exit 1
fi

printf 'Running deterministic remote contracts without Simulator or Docker...\n'
MUGSHOT_QA_DATABASE_URL="${qa_database_url}" MUGSHOT_PRODUCTION_PROJECT_REF="${PRODUCTION_REF}" node "${REPO_ROOT}/qa/pglite/run-remote-contracts.mjs" "$@"
