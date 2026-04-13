{{ config(tags=['finance']) }}

select
    1                             as payment_id,
    100.50                        as payment_amount,
    'completed'                   as status,
    {{ dbt.current_timestamp() }} as paid_at