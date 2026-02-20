from dagster import Definitions
from dagster_dbt import DbtCliResource, load_assets_from_dbt_project
import os

PROJECT_DIR = os.getenv("DBT_PROJECT_DIR", "/workspaces/dbt-project-template")
PROFILES_DIR = os.getenv("DBT_PROFILES_DIR", "/profiles")
DBT_PROFILE = os.getenv("DBT_PROFILE", "dbt_project_template")
DBT_TARGET = os.getenv("DBT_TARGET", "dev")

dbt = DbtCliResource(
    project_dir=PROJECT_DIR,
    profiles_dir=PROFILES_DIR,
    profile=DBT_PROFILE,
    target=DBT_TARGET,
)

dbt_assets = load_assets_from_dbt_project(
    project_dir=PROJECT_DIR,
    profiles_dir=PROFILES_DIR,
)

defs = Definitions(
    assets=[dbt_assets],
    resources={"dbt": dbt},
)
