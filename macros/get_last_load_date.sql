{% macro get_last_load_date(model, date_field) %}
  {%- set get_date_query -%}
    select max({{ date_field }}) as last_load_date
    from {{ model }}
  {%- endset -%}
  {%- set results = run_query(get_date_query) -%}
  {%- if execute -%}
    {%- set last_load_date = results.columns[0].values()[0] -%}
    {%- if last_load_date is none -%}
      {%- set results = run_query("SELECT CAST('" ~ var('dates')["start"] ~ "' AS DATE) as last_load_date") -%}
      {%- set last_load_date = results.columns[0].values()[0] -%}
    {%- endif -%}
  {%- else -%}
    {%- set last_load_date = none -%}
  {%- endif -%}
  {{ return(last_load_date) }}
{% endmacro %}