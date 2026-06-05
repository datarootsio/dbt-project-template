{{ config(materialized='table') }}

select *
from {{ ref('raw_top_terms_hourly') }}