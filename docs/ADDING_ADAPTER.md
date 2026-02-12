# Adding a New Adapter

This template supports multiple adapters via Dev Containers.

Each adapter integration requires three components:

1. Adapter pack (`adapters/<adapter>/`)
2. Dev Container config (`.devcontainer/<adapter>/devcontainer.json`)
3. Runtime image (`dbt-runtime-<adapter>:<version>`)


# Add Adapter Pack

Create a new folder:

```
adapters/<adapter>/
```

## Required files

### env.example

Defines required environment variables.

Example:

```bash
POSTGRES_HOST=
POSTGRES_PORT=5432
POSTGRES_USER=
POSTGRES_PASSWORD=
POSTGRES_DB=
POSTGRES_SCHEMA=public
DBT_THREADS=4
```

When the Dev Container starts, this file is copied to:

```
adapters/<adapter>/.env
```



### profiles.yml.example

Defines how dbt connects using environment variables.

Example:

```yaml
default:
  target: "{{ env_var('DBT_TARGET', 'dev') }}"
  outputs:
    dev:
      type: postgres
      host: "{{ env_var('POSTGRES_HOST') }}"
      port: "{{ env_var('POSTGRES_PORT') | int }}"
      user: "{{ env_var('POSTGRES_USER') }}"
      password: "{{ env_var('POSTGRES_PASSWORD') }}"
      dbname: "{{ env_var('POSTGRES_DB') }}"
      schema: "{{ env_var('POSTGRES_SCHEMA') }}"
      threads: "{{ env_var('DBT_THREADS', '4') | int }}"
```

This file is copied automatically into:

```
/profiles/profiles.yml
```

inside the Dev Container.



# 2Add Dev Container Configuration

Create a new folder:

```
.devcontainer/<adapter>/
```

Inside it, create:

```
.devcontainer/<adapter>/devcontainer.json
```

Example:

```json
{
  "name": "dbt-template (postgres)",
  "image": "ghcr.io/datarootsio/dbt-runtime-postgres:1.8.0",
  "remoteUser": "dbtuser",
  "containerEnv": {
    "ADAPTER": "postgres",
    "DBT_TARGET": "dev",
    "DBT_PROFILES_DIR": "/profiles"
  },
  "postCreateCommand": "bash .devcontainer/postCreate.sh"
}
```

Important:

* The adapter name must match the folder name in `adapters/`.
* The runtime image must already exist in GHCR.



# Runtime Image Requirement

Before adding an adapter to the template, ensure the runtime image exists:

```
ghcr.io/datarootsio/dbt-runtime-<adapter>:<version>
```

This image must include:

* dbt-core
* The adapter package
* Profile rendering logic

If it does not exist, create it in the `dbt-runtime-images` repository first.



# Validation Checklist

After adding a new adapter:

1. Open the repo in VS Code.
2. Run:

   ```
   Dev Containers: Reopen in Container
   ```
3. Choose the new adapter from the list.
4. Confirm:

   * `.env` file is created
   * `profiles.yml` is installed
   * `dbt deps` runs
   * `dbt parse` succeeds

If all checks pass, the adapter integration is complete.

