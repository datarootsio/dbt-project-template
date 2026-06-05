{{ config(tags=['accounting']) }}

select
    1                              as invoice_id,
    'INV-001'                      as invoice_number,
    {{ dbt.current_timestamp() }}  as issued_at,
    100.00                         as invoice_amount,
    cast('2024-12-31' as date)     as due_date