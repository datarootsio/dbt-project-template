# Airflow orchestration (optional)

This is a minimal Airflow scaffold intended for local/dev use.

## Run (inside dev container)
```bash
cd orchestration/airflow
export AIRFLOW_HOME="$PWD/.airflow"
airflow db init
airflow users create --role Admin --username admin --password admin --firstname Admin --lastname User --email admin@example.com
airflow standalone
```

Open: http://localhost:8080  (user: admin / pass: admin)

If you want dbt task orchestration, select the `cosmos` devcontainer instead (it adds an example DAG).
