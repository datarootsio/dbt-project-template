# Usage — dbt project template (containerized)

This project runs dbt **inside a container image** (runtime image). You do **not** install dbt locally.

## Prerequisites
- Docker installed and running
- Access to GHCR images : `docker login ghcr.io`

## Concepts
- **Adapter**: snowflake / fabric / … (select with `ADAPTER=<name>`)
- **Runtime image**: `ghcr.io/<ORG>/dbt-runtime-<adapter>:<DBT_VERSION>`
- **Local env file**: `adapters/<adapter>/.env` (created from `env.example`)
- **Profiles rendering**: runtime image renders `profiles.yml` at runtime using env vars



## 1) First-time local setup (example: Snowflake)

From the dbt project folder:

```bash
cp adapters/snowflake/env.example adapters/snowflake/.env
# edit adapters/snowflake/.env
```

Pull the runtime image:

```bash
make pull ADAPTER=snowflake
```

Install dbt packages:

```bash
make deps ADAPTER=snowflake
```

Validate project compilation (no database required for parse):

```bash
make parse ADAPTER=snowflake
```



## 2) Run common workflows

### Build a selection (recommended)
Use selectors to standardize orchestration:

```bash
make build ADAPTER=snowflake SELECTOR=daily TARGET=dev
make build ADAPTER=snowflake SELECTOR=staging TARGET=dev
make build ADAPTER=snowflake SELECTOR=marts TARGET=dev
```

### Run tests
```bash
make test ADAPTER=snowflake TARGET=dev
```

### Clean artifacts
```bash
make clean
```



## 3) Power mode — run any dbt command

Use `make dbt` when you need a custom dbt command:

```bash
make dbt ADAPTER=snowflake CMD="run -s tag:daily --target dev"
make dbt ADAPTER=snowflake CMD="build --selector daily --full-refresh --target prod"
make dbt ADAPTER=snowflake CMD="docs generate"
make dbt ADAPTER=snowflake CMD="ls -s models/staging"
```



## 4) Debug mode — open a shell in the runtime image

```bash
make shell ADAPTER=snowflake
```

Inside the container, your project is at `/app`.



## 5) CI behavior (what it validates)
Typical CI checks:
- `dbt deps`
- `dbt parse`

These verify:
- project structure is valid
- dependencies resolve
- compilation succeeds
