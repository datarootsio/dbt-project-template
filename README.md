# dbt Project Template — README

## Overview

This project provides a standardized, template for running **dbt** inside a **VS Code Dev Container**, backed by a pre-built runtime image and integrated orchestration.

It is designed for multi-adapter usage and supports modern orchestration patterns out-of-the-box.


## Recommended Workflow (Dev Containers)

### Prerequisites

Ensure the following are installed and configured:

* VS Code
* Dev Containers extension
* Docker (running locally)
* Access to GHCR images (run `docker login ghcr.io` if required)


## Open in Dev Container

1. Open the repository in VS Code
2. Press **Cmd/Ctrl + Shift + P**
3. Select:

```
Dev Containers: Reopen in Container
```

You will be prompted to select a database adapter:

* `snowflake`
* `fabric`
* `databricks`
* `bigquery`
* `postgres`

Choose the adapter corresponding to your target platform.

## Integrated Orchestration

This template includes built-in orchestration capabilities.

It automatically parses your `selectors.yml` and dynamically generates jobs or DAGs based on tags and paths.

### Supported Orchestrators

* **Dagster** — Software-Defined Assets
* **Apache Airflow** — Task-based orchestration (via Astronomer Cosmos)
* **None** — Standard dbt CLI only

### Switching Orchestrators

Update the `ORCHESTRATOR` environment variable in your adapter-specific `devcontainer.json`:

```
"ORCHESTRATOR": "dagster"   # or "airflow" or ""
```

Then rebuild the container.


## Container Initialization (Automated Setup)

When the Dev Container starts, the following happens automatically:

* Pulls the correct runtime image:

  ```
  ghcr.io/datarootsio/dbt-runtime-<adapter>:<version>
  ```
* Creates `adapters/<adapter>/.env` from `env.example` (if missing)
* Generates `profiles.yml` into `/profiles`
* Executes:

  ```bash
  dbt deps
  dbt parse
  ```
* Installs, configures, and starts the selected orchestrator in the background

> Note: The container exports both `ADAPTER` and `DBT_ADAPTER` for compatibility with runtime images.

Your environment is fully initialized and ready for use.


## Configure Credentials

Update the generated environment file:

```
adapters/<adapter>/.env
```

Provide your database credentials.

> Important:
> If using Databricks, Snowflake, or Fabric, the orchestrator UI may not display models until credentials are correctly set and `dbt parse` succeeds.


## Daily Usage

### CLI Usage

Run standard dbt commands inside the container:

```bash
dbt deps
dbt parse
dbt build --selector daily --target dev
dbt test
```


### Orchestrator UI

Access the UI depending on your selected orchestrator:

* **Dagster:** [http://localhost:3000](http://localhost:3000)
* **Airflow:** [http://localhost:8080](http://localhost:8080)

  * Username: `admin`
  * Password: `admin`

Use the UI to trigger and monitor pipelines visually.


## Notes & Best Practices

* Keep `selectors.yml` well-structured — it directly drives orchestration logic
* Use tags and paths consistently to enable dynamic DAG/job generation
* Always run `dbt parse` after updating models or configurations
* Ensure `.env` files are not committed with secrets

## Summary

This template provides:

* Multi-adapter dbt support
* Dev Container-based reproducibility
* Pre-configured runtime images
* Built-in orchestration (Dagster / Airflow)
* Automated project bootstrapping
