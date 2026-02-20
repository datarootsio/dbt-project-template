# Dagster orchestration (optional)

This folder contains a minimal Dagster + dbt setup intended to work with this template.

## How it works
- The devcontainer `postCreate.sh` installs `orchestration/dagster/requirements.txt` when `ORCHESTRATOR=dagster`.
- The Dagster definitions load dbt assets directly from this dbt project.

## Run (inside dev container)
```bash
cd orchestration/dagster
dagster dev -h 0.0.0.0 -p 3000
```

Then open: http://localhost:3000

Notes:
- You must configure dbt credentials in `adapters/<adapter>/.env` and re-run `dbt debug` / `dbt parse` before the assets load cleanly.
