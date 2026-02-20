from __future__ import annotations

import os
from datetime import datetime

from airflow import DAG
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.constants import LoadMode

PROJECT_DIR = os.getenv("DBT_PROJECT_DIR", "/workspaces/dbt-project-template")
PROFILES_DIR = os.getenv("DBT_PROFILES_DIR", "/profiles")
DBT_PROFILE = os.getenv("DBT_PROFILE", "dbt_project_template")
DBT_TARGET = os.getenv("DBT_TARGET", "dev")

with DAG(
    dag_id="dbt_cosmos_example",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["dbt", "cosmos"],
) as dag:

    DbtTaskGroup(
        group_id="dbt",
        project_config=ProjectConfig(
            dbt_project_path=PROJECT_DIR,
            manifest_path=os.path.join(PROJECT_DIR, "target", "manifest.json"),
            load_method=LoadMode.DBT_MANIFEST,
        ),
        profile_config=ProfileConfig(
            profile_name=DBT_PROFILE,
            target_name=DBT_TARGET,
            profiles_yml_filepath=os.path.join(PROFILES_DIR, "profiles.yml"),
        ),
        execution_config=ExecutionConfig(dbt_executable_path="dbt"),
        operator_args={"install_deps": True},
    )
