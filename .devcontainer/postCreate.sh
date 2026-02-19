#!/usr/bin/env bash
set -euo pipefail

log()  { printf "==> %s\n" "$*"; }
warn() { printf "WARN: %s\n" "$*" >&2; }

ADAPTER="${ADAPTER:-snowflake}"
DBT_TARGET="${DBT_TARGET:-dev}"
DBT_PROFILES_DIR="${DBT_PROFILES_DIR:-/profiles}"
RUN_DBT_DEPS="${RUN_DBT_DEPS:-1}"
RUN_DBT_PARSE="${RUN_DBT_PARSE:-1}"

WORKSPACE_ROOT="${WORKSPACE_ROOT:-}"
if [[ -z "${WORKSPACE_ROOT}" ]]; then
  if command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
    WORKSPACE_ROOT="$(git rev-parse --show-toplevel)"
  else
    WORKSPACE_ROOT="$PWD"
  fi
fi

PROJECT_NAME="$(
  awk -F: '
    $1 ~ /^name[[:space:]]*$/ {
      v=$0
      sub(/^[^:]*:[[:space:]]*/, "", v)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      gsub(/^'\''|'\''$/, "", v)
      gsub(/^"|"$/, "", v)
      print v
      exit
    }
  ' "${WORKSPACE_ROOT}/dbt_project.yml" 2>/dev/null || true
)"

DBT_PROFILE="${DBT_PROFILE:-${PROJECT_NAME:-default}}"

ADAPTER_DIR="${WORKSPACE_ROOT}/adapters/${ADAPTER}"
ENV_EXAMPLE="${ADAPTER_DIR}/env.example"
ENV_FILE="${ADAPTER_DIR}/.env"
PROFILES_EXAMPLE="${ADAPTER_DIR}/profiles.yml.example"
PROFILES_FILE="${DBT_PROFILES_DIR%/}/profiles.yml"

log "DevContainer bootstrap"
log "  Workspace: ${WORKSPACE_ROOT}"
log "  Adapter:   ${ADAPTER}"
log "  Target:    ${DBT_TARGET}"
log "  Profile:   ${DBT_PROFILE}"
log "  Profiles:  ${DBT_PROFILES_DIR}"

[[ -d "${ADAPTER_DIR}" ]] || { echo "Adapter folder not found: ${ADAPTER_DIR}"; exit 1; }

if [[ -f "${ENV_EXAMPLE}" && ! -f "${ENV_FILE}" ]]; then
  log "Creating local env file: ${ENV_FILE}"
  cp "${ENV_EXAMPLE}" "${ENV_FILE}"
  warn "Edit ${ENV_FILE} with real credentials before running dbt."
fi

mkdir -p "${DBT_PROFILES_DIR}" || true

if [[ -f "${PROFILES_EXAMPLE}" ]]; then
  cp "${PROFILES_EXAMPLE}" "${PROFILES_FILE}"

  if ! grep -qE "^${DBT_PROFILE}:" "${PROFILES_FILE}"; then
    FIRST_KEY="$(grep -E '^[A-Za-z0-9_-]+:' "${PROFILES_FILE}" | head -n1 | cut -d':' -f1)"
    if [[ -n "${FIRST_KEY}" ]]; then
      sed -i.bak "s/^${FIRST_KEY}:/${DBT_PROFILE}:/" "${PROFILES_FILE}"
      rm -f "${PROFILES_FILE}.bak"
    fi
  fi
fi

add_shell_snippet() {
  local rc="$1"
  local begin="# >>> dbt-template auto-env >>>"
  local end="# <<< dbt-template auto-env <<<"

  mkdir -p "$(dirname "${rc}")"
  touch "${rc}"

  if grep -qF "${begin}" "${rc}"; then
    perl -0777 -i -pe "s/\Q${begin}\E.*?\Q${end}\E\n?//s" "${rc}"
  fi

  cat >> "${rc}" <<EOF

${begin}
export ADAPTER="${ADAPTER}"
export DBT_ADAPTER="${ADAPTER}"
export DBT_TARGET="${DBT_TARGET}"
export DBT_PROFILE="${DBT_PROFILE}"
export DBT_PROFILES_DIR="${DBT_PROFILES_DIR}"

__dbt_tpl_root() {
  if command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    pwd
  fi
}

__dbt_tpl_source_env() {
  local root="\$(__dbt_tpl_root)"
  local env_file="\${root}/adapters/\${ADAPTER}/.env"
  if [[ -f "\${env_file}" ]]; then
    set -a
    source "\${env_file}"
    set +a
  fi
}

__dbt_tpl_source_env
${end}
EOF
}

add_shell_snippet "${HOME}/.bashrc"
add_shell_snippet "${HOME}/.zshrc"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  source "${ENV_FILE}"
  set +a
fi

export ADAPTER DBT_ADAPTER DBT_TARGET DBT_PROFILE DBT_PROFILES_DIR

log "dbt version:"
dbt --version || true

if [[ "${RUN_DBT_DEPS}" == "1" ]]; then
  log "Running: dbt deps"
  (cd "${WORKSPACE_ROOT}" && dbt deps)
fi

if [[ "${RUN_DBT_PARSE}" == "1" ]]; then
  log "Running: dbt parse"
  (cd "${WORKSPACE_ROOT}" && dbt parse --profile "${DBT_PROFILE}" || warn "dbt parse failed (profiles/env not configured yet). You can ignore this during first setup.")
fi

log "Done."
echo
echo "Next:"
echo "  1) Edit adapters/${ADAPTER}/.env"
echo "  2) Run dbt debug --profile ${DBT_PROFILE} --target ${DBT_TARGET}"
echo "  3) Run dbt build --profile ${DBT_PROFILE} --target ${DBT_TARGET}"