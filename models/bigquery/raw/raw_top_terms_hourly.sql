
select *
from {{ source('google_trends_hourly', 'top_terms_hourly') }}