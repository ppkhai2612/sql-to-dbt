with journey_with_conversions as (
    select 
        journey_events.*,
        conversions.conversion_time
    from {{ ref('int_journey_events') }} as journey_events
    inner join {{ ref('int_conversions') }} as conversions 
        on journey_events.visitor_id = conversions.visitor_id 
        and journey_events.event_timestamp <= conversions.conversion_time
)

{{ get_touchpoint_attribution(
    source_table='journey_with_conversions',
    attribution_type='last',
    additional_partitions=['conversion_time']
) }}