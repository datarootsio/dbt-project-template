# Dev Containers

This repository supports **multiple adapters** through separate Dev Container configurations.

## How to Choose an Adapter in VS Code

1. Open the repository in **VS Code**.
2. Open the **Command Palette**.
3. Select **Dev Containers: Switch Container Configuration**.
4. Choose one of the following:

   * `.devcontainer/devcontainer.snowflake.json`
   * `.devcontainer/devcontainer.fabric.json`
5. Run **Dev Containers: Reopen in Container**.

## What Happens Automatically

On the first container start, `.devcontainer/postCreate.sh` will:

* Create `adapters/<adapter>/.env` from `env.example` (if it does not already exist).
* Install `/profiles/profiles.yml` from the adapter pack (if present).
* Automatically load the `.env` file in your terminal so **dbt can read environment variables**.
* Run `dbt deps` and `dbt parse` (this behavior can be disabled if needed).

## Notes

* Edit `adapters/<adapter>/.env` to add real credentials when you want to run `dbt build` or `dbt test`.
* In **CI/production environments**, secrets should be injected from a **secret store**, not committed in `.env` files.

## Selecting an Orchestrator

To switch the active orchestrator, edit the `containerEnv` section in:

```
.devcontainer/devcontainer.json
```

Example:

```json
"containerEnv": {
  "ORCHESTRATOR": "airflow"  // Options: "airflow", "dagster"
}
```

### Rebuild Required

After changing this value:

1. Open the **Command Palette** (`Ctrl/Cmd + Shift + P`).
2. Select **Dev Containers: Rebuild Container**.
