import os
import yaml
from pathlib import Path
from dagster import Definitions, define_asset_job, ScheduleDefinition
from dagster_dbt import DbtCliResource, dbt_assets, build_dbt_asset_selection

DBT_PROJECT_DIR = Path("/workspaces/dbt-project-template").resolve()
SELECTORS_PATH = DBT_PROJECT_DIR / "selectors.yml"
MANIFEST_PATH = DBT_PROJECT_DIR / "target" / "manifest.json"

dbt = DbtCliResource(project_dir=os.fspath(DBT_PROJECT_DIR))

@dbt_assets(manifest=MANIFEST_PATH)
def workspace_dbt_assets(context, dbt: DbtCliResource):
    yield from dbt.cli(["build"], context=context).stream()

jobs = []
schedules = []

if SELECTORS_PATH.exists():
    with open(SELECTORS_PATH, "r") as f:
        config = yaml.safe_load(f)
    
    for selector_block in config.get("selectors", []):
        s_name = selector_block["name"] 
        job = define_asset_job(
            name=f"dbt_{s_name}_job",
            selection=build_dbt_asset_selection(
                [workspace_dbt_assets], 
                dbt_selector=s_name 
            )
        )
        jobs.append(job)
        
        schedules.append(
            ScheduleDefinition(
                name=f"dbt_{s_name}_schedule",
                job=job,
                cron_schedule="0 0 * * *"
            )
        )

defs = Definitions(
    assets=[workspace_dbt_assets],
    jobs=jobs,
    schedules=schedules,
    resources={"dbt": dbt},
)