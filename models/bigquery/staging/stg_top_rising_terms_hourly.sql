select *
from {{ ref('raw_top_rising_terms_hourly') }}
where 1=1
{{ dev_limiter() }}