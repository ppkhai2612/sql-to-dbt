select
    journey_events.visitor_id,
    conversions.conversion_time,
    count(distinct journey_events.event_id) as total_touchpoints,
    count(distinct journey_events.session_id) as total_sessions,
    date_diff('day', min(journey_events.event_timestamp), conversions.conversion_time) as journey_length_days
from {{ ref('int_journey_events') }} as journey_events
inner join {{ ref('int_conversions') }} as conversions
    on journey_events.visitor_id = conversions.visitor_id 
    and journey_events.event_timestamp <= conversions.conversion_time
group by journey_events.visitor_id, conversions.conversion_time