#!/usr/bin/env bash
set -euo pipefail

log()  { printf "==> %s\n" "$*"; }
warn() { printf "WARN: %s\n" "$*" >&2; }

ADAPTER="${ADAPTER:-postgres}"
ORCHESTRATOR="${ORCHESTRATOR:-none}"
DBT_TARGET="${DBT_TARGET:-dev}"
DBT_PROFILE="${DBT_PROFILE:-dbt_project_template}"
DBT_PROFILES_DIR="${DBT_PROFILES_DIR:-/profiles}"
RUN_DBT_DEPS="${RUN_DBT_DEPS:-1}"
RUN_DBT_PARSE="${RUN_DBT_PARSE:-1}"
RUN_ORCHESTRATOR="${RUN_ORCHESTRATOR:-1}"

WORKSPACE_ROOT="${WORKSPACE_ROOT:-}"
if [[ -z "${WORKSPACE_ROOT}" ]]; then
  if command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
    WORKSPACE_ROOT="$(git rev-parse --show-toplevel)"
  else
    WORKSPACE_ROOT="$PWD"
  fi
fi

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

if [[ ! -d "${ADAPTER_DIR}" ]]; then
  printf "ERROR: Adapter folder not found: %s\n" "${ADAPTER_DIR}" >&2
  exit 1
fi

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
    printf "ERROR: Cannot create %s. Set DBT_PROFILES_DIR to a writable path.\n" "${DBT_PROFILES_DIR}" >&2
    exit 1
  fi
}

if [[ -f "${PROFILES_EXAMPLE}" ]]; then
  log "Installing profiles.yml from: ${PROFILES_EXAMPLE}"
  if [[ -f "${PROFILES_FILE}" ]] && ! cmp -s "${PROFILES_EXAMPLE}" "${PROFILES_FILE}"; then
    ts="$(date +%Y%m%d-%H%M%S)"
    log "Existing profiles.yml differs; backing up to: ${PROFILES_FILE}.${ts}.bak"
    cp "${PROFILES_FILE}" "${PROFILES_FILE}.${ts}.bak"
  fi
  cp "${PROFILES_EXAMPLE}" "${PROFILES_FILE}"
else
  warn "No profiles.yml.example found at ${PROFILES_EXAMPLE}. Skipping profiles install."
fi

export ADAPTER DBT_TARGET DBT_PROFILE DBT_PROFILES_DIR
export DBT_ADAPTER="${ADAPTER}"
export DBT_PROJECT_DIR="${WORKSPACE_ROOT}"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

if [[ "${RUN_ORCHESTRATOR}" == "1" ]]; then
  case "${ORCHESTRATOR}" in
    none|"")
      ;;
    airflow)
      if command -v docker >/dev/null 2>&1; then
        log "Starting Airflow (docker compose)"
        docker compose -f "${WORKSPACE_ROOT}/orchestration/airflow/docker-compose.yml" up -d
      else
        warn "docker not available; cannot start Airflow"
      fi
      ;;
    dagster)
      if command -v docker >/dev/null 2>&1; then
        log "Starting Dagster (docker compose)"
        docker compose -f "${WORKSPACE_ROOT}/orchestration/dagster/docker-compose.yml" up -d
      else
        warn "docker not available; cannot start Dagster"
      fi
      ;;
    cosmos)
      if command -v docker >/dev/null 2>&1; then
        log "Starting Cosmos (Airflow + astronomer-cosmos) (docker compose)"
        docker compose -f "${WORKSPACE_ROOT}/orchestration/cosmos/docker-compose.yml" up -d --build
      else
        warn "docker not available; cannot start Cosmos"
      fi
      ;;
    *)
      warn "Unknown ORCHESTRATOR='${ORCHESTRATOR}' (expected: none|airflow|dagster|cosmos)"
      ;;
  esac
fi

log "dbt version:"
if command -v dbt >/dev/null 2>&1; then
  dbt --version || true
else
  warn "dbt not found in PATH inside container."
fi

if [[ "${RUN_DBT_DEPS}" == "1" ]]; then
  log "Running: dbt deps"
  (cd "${WORKSPACE_ROOT}" && dbt deps) || warn "dbt deps failed."
else
  log "Skipping dbt deps (RUN_DBT_DEPS=${RUN_DBT_DEPS})"
fi

if [[ "${RUN_DBT_PARSE}" == "1" ]]; then
  log "Running: dbt parse"
  (cd "${WORKSPACE_ROOT}" && dbt parse --profile "${DBT_PROFILE}" --target "${DBT_TARGET}") || warn "dbt parse failed (credentials not configured yet)."
else
  log "Skipping dbt parse (RUN_DBT_PARSE=${RUN_DBT_PARSE})"
fi

log "Done."
echo
echo "Next:"
echo "  1) Edit adapters/${ADAPTER}/.env"
echo "  2) Run dbt debug --profile ${DBT_PROFILE} --target ${DBT_TARGET}"
echo "  3) Run dbt build --profile ${DBT_PROFILE} --target ${DBT_TARGET}"