
select *
from {{ source('google_trends_hourly', 'top_rising_terms_hourly') }}