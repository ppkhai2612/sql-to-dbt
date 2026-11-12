{{ get_touchpoint_attribution(
    source_table=ref('int_journey_events'),
    attribution_type='first'
) }}