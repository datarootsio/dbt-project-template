# Airflow + Cosmos orchestration (optional)

Cosmos lets you orchestrate dbt with Airflow.

## Run (inside dev container)
```bash
cd orchestration/cosmos
export AIRFLOW_HOME="$PWD/.airflow"
airflow db init
airflow users create --role Admin --username admin --password admin --firstname Admin --lastname User --email admin@example.com
airflow standalone
```

Open: http://localhost:8080  (user: admin / pass: admin)

The example DAG reads:
- dbt project: repository root (mounted at `/workspaces/...`)
- profiles dir: `/profiles` (written by postCreate)
- profile name: `DBT_PROFILE` (default: dbt_project_template)
- target: `DBT_TARGET` (default: dev)
