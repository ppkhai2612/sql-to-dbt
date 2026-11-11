

{% macro safe_divide(numerator, denominator) %}
    case
        when {{ denominator }} > 0 then {{ numerator }} / {{ denominator }}
        else null
    end
{% endmacro %}