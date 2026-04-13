select
    1                             as customer_id,
    1                             as campaign_id,
    99                            as product_id,
    {{ dbt.current_timestamp() }} as ordered_at,
    250.00                        as total_amount,
    0.20                          as tax_rate
