{% macro filter_incrementality(incremental_column,datepart, interval, max_date) %}
    {%- set results = run_query("SELECT CAST('" ~ var('dates')["start"] ~"'AS DATE) as draw_date") -%}
    {%- set default_date = results.columns[0].values()[0] -%}
    {% if execute %}
        {% if not max_date == default_date %}
            and {{ incremental_column }} >
            {{ dbt.dateadd(
                datepart=datepart,
                interval=interval,
                from_date_or_timestamp= "'" ~ max_date.strftime('%Y-%m-%d') ~ "'"
            ) }}
        {% endif %}
    {% endif %}
{% endmacro %}