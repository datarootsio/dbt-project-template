{{ config(tags=["daily"]) }}

select
  current_timestamp as run_ts,
  1 as example_metric
