select
    1                             as order_item_id,
    29.99                         as unit_price,
    0.10                          as discount_pct,
    {{ dbt.current_timestamp() }} as created_at
