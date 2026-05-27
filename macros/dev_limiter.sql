{%- macro dev_limiter() -%}
  {#
    Usage by adapter — place the macro call after WHERE 1=1:
      sqlserver / fabric / synapse : SELECT {{ dev_limiter() }} * FROM ... WHERE 1=1 ...
      bigquery                     : SELECT * FROM ... WHERE 1=1 ... {{ dev_limiter() }}
      postgres / snowflake         : SELECT * FROM ... WHERE 1=1 ... {{ dev_limiter() }}

    Note: all models must have WHERE 1=1 for bigquery schema_only_build to work correctly.
  #}
  {%- set adapter_type = target.type -%}

  {%- if var('schema_only_build', false) -%}
    {%- if adapter_type in ('sqlserver', 'fabric', 'synapse') -%}
      top 0
    {%- elif adapter_type == 'bigquery' -%}
      and false limit 1
    {%- else -%}
      limit 0
    {%- endif -%}

  {%- elif var('enable_limiting', 'no_limit') == 'limit' -%}
    {%- if adapter_type in ('sqlserver', 'fabric', 'synapse') -%}
      top 1000
    {%- else -%}
      limit 1000
    {%- endif -%}

  {%- endif -%}
{%- endmacro -%}