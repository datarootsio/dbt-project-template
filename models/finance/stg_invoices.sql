{{ config(tags=['accounting']) }}

select 
    1 as invoice_id,
    'INV-001' as invoice_number,
    CURRENT_DATE as issued_at