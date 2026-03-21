import os
import yaml
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv

from airflow import DAG 

from cosmos import DbtDag, ProjectConfig, ProfileConfig, ExecutionConfig, RenderConfig

DBT_PROJECT_DIR = Path(__file__).parent.parent.parent.parent.resolve()
SELECTORS_PATH = DBT_PROJECT_DIR / "selectors.yml"

ADAPTER = os.getenv("ADAPTER", "postgres")
env_file = DBT_PROJECT_DIR / "adapters" / ADAPTER / ".env"
if env_file.exists():
    load_dotenv(env_file)

project_config = ProjectConfig(
    dbt_project_path=os.fspath(DBT_PROJECT_DIR),
    env_vars=dict(os.environ),
)

profile_config = ProfileConfig(
    profile_name=os.getenv("DBT_PROFILE", "dbt_project_template"),
    target_name=os.getenv("DBT_TARGET", "dev"),
    profiles_yml_filepath=Path(os.getenv("DBT_PROFILES_DIR", "/profiles")) / "profiles.yml"
)

execution_config = ExecutionConfig(
    dbt_executable_path="/usr/local/bin/dbt",
)

if not SELECTORS_PATH.exists():
    raise FileNotFoundError(f"Cannot find the selectors file! Looking at: {SELECTORS_PATH}")

selectors_list = []
with open(SELECTORS_PATH, "r") as f:
    config = yaml.safe_load(f)
    if not config or "selectors" not in config:
        raise ValueError(f"The file at {SELECTORS_PATH} is empty or missing the 'selectors:' key.")
    
    selectors_list = [selector["name"] for selector in config["selectors"]]

if not selectors_list:
    raise ValueError(f"Found the file, but no selectors were listed inside it!")

for selector_name in selectors_list:
    dag_id = f"dbt_{selector_name}_dag"
    
    globals()[dag_id] = DbtDag(
        dag_id=dag_id,
        schedule_interval="@daily",
        start_date=datetime(2024, 1, 1),
        catchup=False,
        tags=["dbt", "cosmos", selector_name],
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        render_config=RenderConfig(
            selector=selector_name
        ),
    )