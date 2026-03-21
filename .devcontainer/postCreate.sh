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
fi

export ADAPTER DBT_TARGET DBT_PROFILE DBT_PROFILES_DIR
export DBT_ADAPTER="${ADAPTER}"
export DBT_PROJECT_DIR="${WORKSPACE_ROOT}"

if [[ -f "${ENV_FILE}" ]]; then
  log "Loading env from: ${ENV_FILE}"
  set -a
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      export "$line"
    else
      warn "Skipping invalid .env line: $line"
    fi
  done < "${ENV_FILE}"
  set +a
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
fi

if [[ "${RUN_DBT_PARSE}" == "1" ]]; then
  case "${ADAPTER}" in
    databricks)
      if [[ -z "${DATABRICKS_HOST:-}" || -z "${DATABRICKS_HTTP_PATH:-}" || -z "${DATABRICKS_SCHEMA:-}" ]]; then
        warn "Skipping dbt parse: Databricks env vars not configured yet."
        RUN_DBT_PARSE=0
      fi
      if [[ "${DATABRICKS_CATALOG+x}" == "x" && -z "${DATABRICKS_CATALOG}" ]]; then
        unset DATABRICKS_CATALOG
        export DATABRICKS_CATALOG
      fi
      ;;
    snowflake)
      if [[ -z "${SNOWFLAKE_ACCOUNT:-}" || -z "${SNOWFLAKE_USER:-}" || -z "${SNOWFLAKE_WAREHOUSE:-}" || -z "${SNOWFLAKE_DATABASE:-}" || -z "${SNOWFLAKE_SCHEMA:-}" ]]; then
        warn "Skipping dbt parse: Snowflake env vars not configured yet."
        RUN_DBT_PARSE=0
      fi
      ;;
    fabric)
      if [[ -z "${FABRIC_SERVER:-}" || -z "${FABRIC_DATABASE:-}" || -z "${FABRIC_SCHEMA:-}" ]]; then
        warn "Skipping dbt parse: Fabric env vars not configured yet."
        RUN_DBT_PARSE=0
      fi
      ;;
  esac
fi

if [[ "${RUN_DBT_PARSE}" == "1" ]]; then
  log "Running: dbt parse"
  (cd "${WORKSPACE_ROOT}" && dbt parse --profile "${DBT_PROFILE}" --target "${DBT_TARGET}") \
    || warn "dbt parse failed (credentials not configured yet)."
else
  log "Skipping dbt parse (RUN_DBT_PARSE=${RUN_DBT_PARSE})"
fi

if [[ "${RUN_ORCHESTRATOR}" == "1" ]]; then
  case "${ORCHESTRATOR}" in
    none|"")
      log "No orchestrator selected. Skipping orchestration setup."
      ;;
    dagster)
      log "Installing Dagster dependencies..."
      
      python3 -m pip install --user --break-system-packages --upgrade pip > /dev/null 2>&1
      python3 -m pip cache purge || true
      python3 -m pip install --user --break-system-packages --no-cache-dir --default-timeout=100 dagster dagster-webserver dagster-dbt pyyaml
      
      export PATH="$HOME/.local/bin:$PATH"
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
      
      log "Starting Dagster UI on port 3000..."
      export DAGSTER_HOME="${WORKSPACE_ROOT}/.dagster"
      echo "export DAGSTER_HOME=\"${DAGSTER_HOME}\"" >> ~/.bashrc
      mkdir -p "$DAGSTER_HOME"
      
      nohup dagster dev -f "${WORKSPACE_ROOT}/orchestration/dagster/definitions.py" -h 0.0.0.0 -p 3000 > /tmp/dagster.log 2>&1 &
      disown
      
      log "Dagster started successfully! UI will be available on port 3000."
      ;;
    airflow|cosmos)
      log "Installing Apache Airflow (Stable SQLite Mode)..."
      
      AIRFLOW_VERSION="2.10.5"
      PYTHON_VERSION="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
      CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
      
      rm -rf ~/.airflow_venv ~/airflow
      python3 -m venv ~/.airflow_venv
      
      ~/.airflow_venv/bin/pip install --upgrade pip > /dev/null 2>&1
      ~/.airflow_venv/bin/pip install --no-cache-dir --default-timeout=100 \
        "apache-airflow==${AIRFLOW_VERSION}" astronomer-cosmos python-dotenv pyyaml \
        --constraint "${CONSTRAINT_URL}"
      
      ~/.airflow_venv/bin/pip install "werkzeug==2.2.3"
      
      export PATH="$HOME/.airflow_venv/bin:$PATH"
      echo 'export PATH="$HOME/.airflow_venv/bin:$PATH"' >> ~/.bashrc
      
      export AIRFLOW_HOME="$HOME/airflow"
      export AIRFLOW__CORE__DAGS_FOLDER="${WORKSPACE_ROOT}/orchestration/airflow/dags"
      export AIRFLOW__CORE__LOAD_EXAMPLES="False"
      
      echo "export AIRFLOW_HOME=\"$HOME/airflow\"" >> ~/.bashrc
      
      log "Initializing Airflow Database..."
      airflow db migrate > /dev/null 2>&1 || true
      
      log "Creating Airflow Admin user..."
      airflow users create --username admin --password admin --firstname Admin --lastname User --role Admin --email admin@example.com || true
      
      log "Starting Airflow Services..."
      nohup airflow webserver -p 8080 > /tmp/airflow_webserver.log 2>&1 &
      nohup airflow scheduler > /tmp/airflow_scheduler.log 2>&1 &
      disown -a
      
      log "Airflow started! UI available on port 8080 (admin/admin)."
      ;;
    *)
      warn "Unknown or unsupported ORCHESTRATOR='${ORCHESTRATOR}' in native mode."
      ;;
  esac
fi

log "Done."
echo
echo "Next:"
echo "  1) Edit adapters/${ADAPTER}/.env"
echo "  2) Run: dbt debug --profile ${DBT_PROFILE} --target ${DBT_TARGET}"
echo "  3) Run: dbt build --profile ${DBT_PROFILE} --target ${DBT_TARGET}"