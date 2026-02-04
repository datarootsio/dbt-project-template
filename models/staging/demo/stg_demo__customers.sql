with src as (
  select *
  from {{ source('demo', 'raw_customers') }}
)
select
  cast(customer_id as varchar) as customer_id,
  cast(full_name as varchar)   as full_name,
  cast(created_at as timestamp) as created_at
from src
