# Adding a new dbt adapter to this template

This template is **adapter-agnostic**: adapter-specific configuration lives under `adapters/<adapter>/`,
and execution happens in the matching runtime image:

- `ghcr.io/<ORG>/dbt-runtime-<adapter>:<DBT_VERSION>`

## What you must add

### 1) Adapter folder
Create:

```
adapters/<adapter>/
  env.example
  profiles.yml.example   (recommended)
  README.md              (recommended)
```

### 2) `env.example` (required)
This file documents the minimum environment variables required to connect.

Example structure:

```env
DBT_ADAPTER=<adapter>
DBT_THREADS=4

# <ADAPTER>_... credentials/config
# e.g. for postgres:
PGHOST=...
PGUSER=...
PGPASSWORD=...
PGDATABASE=...
PGSCHEMA=...
```

Developers copy it locally:

```bash
cp adapters/<adapter>/env.example adapters/<adapter>/.env
# edit adapters/<adapter>/.env
```

> `.env` files must be ignored by git (this repo already ignores `adapters/*/.env`).

### 3) `profiles.yml.example` (recommended)
This documents how the runtime image will render a dbt profile from env vars.

Use env_var() everywhere (no hardcoded secrets):

```yaml
default:
  target: "{{ env_var('DBT_TARGET', 'dev') }}"
  outputs:
    dev:
      type: <adapter>
      threads: "{{ env_var('DBT_THREADS', '4') | int }}"
      # adapter-specific fields:
      host: "{{ env_var('PGHOST') }}"
      user: "{{ env_var('PGUSER') }}"
      password: "{{ env_var('PGPASSWORD') }}"
      dbname: "{{ env_var('PGDATABASE') }}"
      schema: "{{ env_var('PGSCHEMA') }}"
```

### 4) Runtime image (outside this template, but required)
In your **dbt runtime images repo**, you must build and publish:

- `dbt-runtime-<adapter>`

Then developers can run:

```bash
make parse ADAPTER=<adapter>
make build ADAPTER=<adapter> SELECTOR=daily TARGET=dev
```

## Optional: add examples for common commands
If this adapter typically needs special dbt flags, document them in:

- `adapters/<adapter>/README.md`

Example:

- `--full-refresh`
- `--threads`
- `--vars '{...}'`
- adapter-specific connection notes (auth, endpoints, drivers)

