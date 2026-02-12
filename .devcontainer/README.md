# Dev Containers (Option B: single template repo)

This repo supports **multiple adapters** via multiple devcontainer configs.

## How to choose an adapter in VS Code
1. Open the repo in VS Code.
2. Command Palette → **Dev Containers: Switch Container Configuration**
3. Choose one of:
   - `.devcontainer/devcontainer.snowflake.json`
   - `.devcontainer/devcontainer.fabric.json`
4. Command Palette → **Dev Containers: Reopen in Container**

## What happens automatically
On first container start, `.devcontainer/postCreate.sh` will:
- Create `adapters/<adapter>/.env` from `env.example` (if missing)
- Install `/profiles/profiles.yml` from the adapter pack (if present)
- Auto-load the `.env` in your terminal (so dbt can read env vars)
- Run `dbt deps` and `dbt parse` (can be disabled)

## Notes
- Edit `adapters/<adapter>/.env` for real credentials when you want to run `dbt build/test`.
- CI/Prod should inject secrets from a secret store, not commit `.env`.
