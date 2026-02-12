#!/usr/bin/env bash
set -euo pipefail

log()  { printf "==> %s\n" "$*"; }
warn() { printf "WARN: %s\n" "$*" >&2; }
err()  { printf "ERROR: %s\n" "$*" >&2; exit 1; }

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

ADAPTER_DIR="${WORKSPACE_ROOT}/adapters/${ADAPTER}"
ENV_EXAMPLE="${ADAPTER_DIR}/env.example"
ENV_FILE="${ADAPTER_DIR}/.env"
PROFILES_EXAMPLE="${ADAPTER_DIR}/profiles.yml.example"
PROFILES_FILE="${DBT_PROFILES_DIR%/}/profiles.yml"

log "DevContainer bootstrap"
log "  Workspace: ${WORKSPACE_ROOT}"
log "  Adapter:   ${ADAPTER}"
log "  Target:    ${DBT_TARGET}"
log "  Profiles:  ${DBT_PROFILES_DIR}"

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
    err "Cannot create ${DBT_PROFILES_DIR}. Try setting DBT_PROFILES_DIR to a writable path."
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
  warn "No profiles.yml.example found for '${ADAPTER}' at ${PROFILES_EXAMPLE}. Skipping profiles install."
fi

add_shell_snippet() {
  local rc="$1"
  local marker_begin="# >>> dbt-template auto-env >>>"
  local marker_end="# <<< dbt-template auto-env <<<"

  mkdir -p "$(dirname "${rc}")"
  touch "${rc}"

  if grep -qF "${marker_begin}" "${rc}"; then
    log "Updating existing auto-env block in ${rc}"
    # Delete old block
    perl -0777 -i -pe "s/\Q${marker_begin}\E.*?\Q${marker_end}\E\n?//s" "${rc}"
  else
    log "Adding auto-env block to ${rc}"
  fi

  cat >> "${rc}" <<EOF

${marker_begin}
# Auto-load adapter env file (safe; do NOT commit adapters/*/.env)
export ADAPTER="${ADAPTER}"
export DBT_TARGET="${DBT_TARGET}"
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
    # shellcheck disable=SC1090
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
export ADAPTER DBT_TARGET DBT_PROFILES_DIR

log "dbt version:"
if command -v dbt >/dev/null 2>&1; then
  dbt --version || true
else
  warn "dbt not found in PATH inside container. Check your devcontainer image."
fi

if [[ "${RUN_DBT_DEPS}" == "1" ]]; then
  log "Running: dbt deps"
  (cd "${WORKSPACE_ROOT}" && dbt deps)
else
  log "Skipping dbt deps (RUN_DBT_DEPS=${RUN_DBT_DEPS})"
fi

if [[ "${RUN_DBT_PARSE}" == "1" ]]; then
  log "Running: dbt parse"
  (cd "${WORKSPACE_ROOT}" && dbt parse)
else
  log "Skipping dbt parse (RUN_DBT_PARSE=${RUN_DBT_PARSE})"
fi

log "Done."
echo
echo "Next (inside the dev container):"
echo "  dbt build --selector daily --target ${DBT_TARGET}"
