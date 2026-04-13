select
    1                             as customer_id,
    49.99                         as monthly_fee,
    0.05                          as churn_ratio,
    0.15                          as upsell_percent,
    {{ dbt.current_timestamp() }} as subscribed_at,
    cast('2024-01-01' as date)    as start_date,
    cast('2024-12-31' as date)    as end_date
