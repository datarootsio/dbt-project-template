#!/usr/bin/env bash
set -euo pipefail

log(){ printf "==> %s\n" "$*"; }
warn(){ printf "WARN: %s\n" "$*" >&2; }
err(){ printf "ERROR: %s\n" "$*" >&2; exit 1; }

ADAPTER="${ADAPTER:-snowflake}"
ORCHESTRATOR="${ORCHESTRATOR:-none}"
DBT_TARGET="${DBT_TARGET:-dev}"
DBT_PROFILE="${DBT_PROFILE:-dbt_project_template}"
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

export DBT_PROJECT_DIR="${DBT_PROJECT_DIR:-${WORKSPACE_ROOT}}"

ADAPTER_DIR="${WORKSPACE_ROOT}/adapters/${ADAPTER}"
ENV_EXAMPLE="${ADAPTER_DIR}/env.example"
ENV_FILE="${ADAPTER_DIR}/.env"
PROFILES_EXAMPLE="${ADAPTER_DIR}/profiles.yml.example"
PROFILES_FILE="${DBT_PROFILES_DIR%/}/profiles.yml"

log "DevContainer bootstrap"
log "  Workspace:     ${WORKSPACE_ROOT}"
log "  Adapter:       ${ADAPTER}"
log "  Orchestrator:  ${ORCHESTRATOR}"
log "  Target:        ${DBT_TARGET}"
log "  Profile:       ${DBT_PROFILE}"
log "  Profiles dir:  ${DBT_PROFILES_DIR}"

[[ -d "${ADAPTER_DIR}" ]] || err "Adapter folder not found: ${ADAPTER_DIR}"

if [[ -f "${ENV_EXAMPLE}" && ! -f "${ENV_FILE}" ]]; then
  log "Creating local env file: ${ENV_FILE}"
  cp "${ENV_EXAMPLE}" "${ENV_FILE}"
  warn "Edit ${ENV_FILE} with real credentials before running dbt build/test."
elif [[ ! -f "${ENV_EXAMPLE}" ]]; then
  warn "Missing ${ENV_EXAMPLE} (cannot scaffold .env)."
fi

log "Ensuring DBT profiles dir exists: ${DBT_PROFILES_DIR}"
mkdir -p "${DBT_PROFILES_DIR}" 2>/dev/null || {
  if command -v sudo >/dev/null 2>&1; then
    sudo mkdir -p "${DBT_PROFILES_DIR}"
    sudo chown -R "$(id -u):$(id -g)" "${DBT_PROFILES_DIR}"
  else
    err "Cannot create ${DBT_PROFILES_DIR}. Set DBT_PROFILES_DIR to a writable path."
  fi
}

if [[ -f "${PROFILES_EXAMPLE}" ]]; then
  log "Installing profiles.yml from: ${PROFILES_EXAMPLE}"
  if [[ -f "${PROFILES_FILE}" ]] && ! cmp -s "${PROFILES_EXAMPLE}" "${PROFILES_FILE}"; then
    ts="$(date +%Y%m%d-%H%M%S)"
    cp "${PROFILES_FILE}" "${PROFILES_FILE}.${ts}.bak" || true
  fi
  cp "${PROFILES_EXAMPLE}" "${PROFILES_FILE}"
else
  warn "No profiles.yml.example found for '${ADAPTER}' at ${PROFILES_EXAMPLE}"
fi

add_shell_snippet() {
  local rc="$1"
  local marker_begin="# >>> dbt-template auto-env >>>"
  local marker_end="# <<< dbt-template auto-env <<<"

  mkdir -p "$(dirname "${rc}")"
  touch "${rc}"

  if grep -qF "${marker_begin}" "${rc}"; then
    perl -0777 -i -pe "s/\Q${marker_begin}\E.*?\Q${marker_end}\E\n?//s" "${rc}"
  fi

  cat >> "${rc}" <<EOF

${marker_begin}
export ADAPTER="${ADAPTER}"
export ORCHESTRATOR="${ORCHESTRATOR}"
export DBT_TARGET="${DBT_TARGET}"
export DBT_PROFILE="${DBT_PROFILE}"
export DBT_PROFILES_DIR="${DBT_PROFILES_DIR}"
export DBT_PROJECT_DIR="${DBT_PROJECT_DIR}"

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
${marker_end}
EOF
}

add_shell_snippet "${HOME}/.bashrc"
add_shell_snippet "${HOME}/.zshrc"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  source "${ENV_FILE}"
  set +a
fi

export ADAPTER ORCHESTRATOR DBT_TARGET DBT_PROFILE DBT_PROFILES_DIR DBT_PROJECT_DIR

if [[ "${ORCHESTRATOR}" != "none" ]]; then
  ORCH_DIR="${WORKSPACE_ROOT}/orchestration/${ORCHESTRATOR}"
  REQ="${ORCH_DIR}/requirements.txt"
  if [[ -f "${REQ}" ]]; then
    log "Installing orchestrator requirements: ${REQ}"
    if [[ "${ORCHESTRATOR}" == "airflow" || "${ORCHESTRATOR}" == "cosmos" ]]; then
      AIRFLOW_VERSION="${AIRFLOW_VERSION:-2.9.3}"
      PY_MM="$(python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
      CONSTRAINTS_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PY_MM}.txt"
      python -m pip install --no-cache-dir -r "${REQ}" -c "${CONSTRAINTS_URL}" || warn "Orchestrator install failed (airflow/cosmos)."
    else
      python -m pip install --no-cache-dir -r "${REQ}" || warn "Orchestrator install failed."
    fi
  else
    warn "Missing orchestrator requirements: ${REQ}"
  fi
fi

log "dbt version:"
if command -v dbt >/dev/null 2>&1; then
  dbt --version || true
else
  warn "dbt not found in PATH."
fi

if [[ "${RUN_DBT_DEPS}" == "1" ]]; then
  log "Running: dbt deps"
  (cd "${WORKSPACE_ROOT}" && dbt deps --profile "${DBT_PROFILE}" --target "${DBT_TARGET}") || warn "dbt deps failed."
else
  log "Skipping dbt deps"
fi

if [[ "${RUN_DBT_PARSE}" == "1" ]]; then
  log "Running: dbt parse"
  (cd "${WORKSPACE_ROOT}" && dbt parse --profile "${DBT_PROFILE}" --target "${DBT_TARGET}") || warn "dbt parse failed (credentials not configured yet)."
else
  log "Skipping dbt parse"
fi

log "Done."
echo
echo "Next:"
echo "  1) Edit adapters/${ADAPTER}/.env"
echo "  2) Run dbt debug --profile ${DBT_PROFILE} --target ${DBT_TARGET}"
echo "  3) Run dbt build --profile ${DBT_PROFILE} --target ${DBT_TARGET}"
if [[ "${ORCHESTRATOR}" == "dagster" ]]; then
  echo "  4) Run dagster dev -h 0.0.0.0 -p 3000 (from orchestration/dagster)"
elif [[ "${ORCHESTRATOR}" == "airflow" || "${ORCHESTRATOR}" == "cosmos" ]]; then
  echo "  4) Run airflow standalone (from orchestration/${ORCHESTRATOR})"
fi
