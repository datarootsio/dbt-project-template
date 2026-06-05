{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        unique_key=['dma_id'],
        partition_by={
            'field': 'refresh_time',
            'data_type': 'datetime',
            'granularity': 'day'
        }
    )
}}

{%- set last_load_date = none -%}
{%- if is_incremental() -%}
    {%- set last_load_date = get_last_load_date(
        model=this,
        date_field='refresh_time'
    ) -%}
{%- endif -%}

with source as (
    select *
    from {{ ref('stg_top_rising_terms_hourly') }}
    where 1=1
    {{ dev_limiter() }}
),

final as (
    select *
    from source
    {% if is_incremental() %}
    where 1=1
        {{ filter_incrementality(
            incremental_column='refresh_time',
            datepart=var('default_buffer')[0],
            interval=var('default_buffer')[1],
            max_date=last_load_date
        ) }}
    {% endif %}
)

select * from final