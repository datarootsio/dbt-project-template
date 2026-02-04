select
  customer_id,
  full_name,
  created_at
from {{ ref('stg_demo__customers') }}
