{#-
  Land models in the schema configured on the model/folder (e.g. PLATFORM_DEMO)
  verbatim, instead of dbt's default behaviour of prefixing the target schema.
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
