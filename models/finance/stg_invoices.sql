{{ config(tags=['accounting']) }}

select 
    1 as invoice_id,
    'INV-001' as invoice_number,
    {{ dbt.current_timestamp()}} as issued_at