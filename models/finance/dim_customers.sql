select
    1                             as customer_id,
    'alice@example.com'           as email,
    500.00                        as lifetime_revenue,
    20.00                         as acquisition_cost,
    {{ dbt.current_timestamp() }} as created_at,
    cast('2024-01-01' as date)    as valid_from,
    cast('2099-12-31' as date)    as valid_to
