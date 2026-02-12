#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARN:  $*" >&2; }

echo "==> Validating dbt template structure"

# Required files
for f in dbt_project.yml packages.yml selectors.yml README.md; do
  [[ -f "$f" ]] || fail "Missing required file: $f"
done

# Required folders
for d in adapters models macros tests .devcontainer; do
  [[ -d "$d" ]] || fail "Missing required folder: $d"
done

echo "==> Validating adapters"
shopt -s nullglob
for path in adapters/*; do
  [[ -d "$path" ]] || continue
  adapter="$(basename "$path")"

  echo "  - $adapter"

  [[ -f "adapters/$adapter/env.example" ]] \
    || fail "Missing adapters/$adapter/env.example"

  [[ -f "adapters/$adapter/profiles.yml.example" ]] \
    || fail "Missing adapters/$adapter/profiles.yml.example"

  [[ -f ".devcontainer/$adapter/devcontainer.json" ]] \
    || fail "Missing .devcontainer/$adapter/devcontainer.json"

  if [[ -f "adapters/$adapter/.env" ]]; then
    warn "adapters/$adapter/.env exists. Should not be committed."
  fi
done

echo "==> OK"
