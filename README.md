# Usage — dbt Project Template

This project runs dbt inside a **VS Code Dev Container** using a pre-built runtime image.

# Recommended Workflow (Dev Containers)

## Prerequisites

* VS Code
* Dev Containers extension installed
* Docker running
* Access to GHCR images (`docker login ghcr.io` if required)


## Open in Dev Container

1. Open this repository in VS Code.
2. Press **Cmd/Ctrl + Shift + P**.
3. Select:

```
Dev Containers: Reopen in Container
```

Because multiple adapter configurations exist, VS Code will prompt you to choose one:

* `snowflake`
* `fabric`

Select the adapter you want to use.


## What Happens Automatically

When the container starts:

* The correct runtime image is used:
  `ghcr.io/datarootsio/dbt-runtime-<adapter>:<version>`
* `adapters/<adapter>/.env` is created from `env.example` (if missing)
* `profiles.yml` is generated into `/profiles`
* `dbt deps` runs automatically
* `dbt parse` runs automatically

Your environment is now ready.

## Daily Usage

Inside the container terminal:

```bash
dbt deps
dbt parse
dbt build --selector daily --target dev
dbt test
```

# Configure Credentials

Edit the generated file:

```
adapters/<adapter>/.env
```

Fill in your database credentials before running `dbt build` or `dbt test`.
