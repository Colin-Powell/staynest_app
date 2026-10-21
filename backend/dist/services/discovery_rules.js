export const NEW_LISTING_WINDOW_DAYS = 30;
export const TRENDING_WINDOW_DAYS = 7;
export const TRENDING_MIN_UNIQUE_TENANTS = 3;
export const TRENDING_MIN_ENGAGEMENT_SCORE = 10;
export const TRENDING_MIN_EXPOSURES = 3;
export const TRENDING_IMPRESSION_EVENT_TYPES = ['property_impression'];
export const TRENDING_EVENT_WEIGHTS = {
    property_view: 1,
    property_save: 5,
    property_share: 3,
};
export function buildTrendingPropertiesQuery(filters, limitParameter) {
    const eventTypes = Object.keys(TRENDING_EVENT_WEIGHTS)
        .map((eventType) => `'${eventType.replace(/'/g, "''")}'`)
        .join(', ');
    const eventWeights = Object.entries(TRENDING_EVENT_WEIGHTS)
        .map(([eventType, weight]) => `WHEN '${eventType}' THEN ${weight}`)
        .join('\n            ');
    const impressionEventTypes = TRENDING_IMPRESSION_EVENT_TYPES
        .map((eventType) => `'${eventType}'`)
        .join(', ');
    return `WITH recent_events AS (
    SELECT DISTINCT ON (ee.property_id, ee.user_id, ee.event_type)
           ee.property_id, ee.user_id, ee.event_type
      FROM engagement_events ee
      JOIN users actor ON actor.id = ee.user_id
     WHERE ee.user_id IS NOT NULL
       AND actor.roles @> ARRAY['tenant']::text[]
       AND ee.event_type = ANY(ARRAY[${eventTypes}]::text[])
       AND ee.created_at >= NOW() - INTERVAL '${TRENDING_WINDOW_DAYS} days'
     ORDER BY ee.property_id, ee.user_id, ee.event_type, ee.created_at DESC
  ), event_scores AS (
    SELECT property_id,
           COUNT(DISTINCT user_id)::int AS unique_tenants,
           SUM(CASE event_type
            ${eventWeights}
            ELSE 0
           END)::numeric AS engagement_score
      FROM recent_events
     GROUP BY property_id
  ), recent_exposures AS (
    SELECT property_id, COUNT(*)::int AS exposure_count
      FROM (
        SELECT DISTINCT ee.property_id, ee.user_id,
               ee.created_at::date AS exposure_date
          FROM engagement_events ee
          JOIN users actor ON actor.id = ee.user_id
         WHERE actor.roles @> ARRAY['tenant']::text[]
           AND ee.event_type = ANY(ARRAY[${impressionEventTypes}]::text[])
           AND ee.user_id IS NOT NULL
           AND ee.created_at >= NOW() - INTERVAL '${TRENDING_WINDOW_DAYS} days'
      ) exposures
     GROUP BY property_id
  ), recent_booking_intent AS (
    SELECT property_id, COUNT(DISTINCT tenant_id)::int AS booking_tenants
      FROM bookings
     WHERE status IN ('pending', 'confirmed', 'completed')
       AND created_at >= NOW() - INTERVAL '${TRENDING_WINDOW_DAYS} days'
     GROUP BY property_id
  ), ranked_properties AS (
    SELECT es.property_id,
           es.unique_tenants,
           es.engagement_score + COALESCE(bi.booking_tenants, 0) * 15 AS weighted_score,
           re.exposure_count,
           (es.engagement_score + COALESCE(bi.booking_tenants, 0) * 15) /
             GREATEST(re.exposure_count, 1) AS engagement_rate
      FROM event_scores es
      JOIN recent_exposures re ON re.property_id = es.property_id
      LEFT JOIN recent_booking_intent bi ON bi.property_id = es.property_id
     WHERE es.unique_tenants >= ${TRENDING_MIN_UNIQUE_TENANTS}
       AND re.exposure_count >= ${TRENDING_MIN_EXPOSURES}
       AND es.engagement_score + COALESCE(bi.booking_tenants, 0) * 15 >= ${TRENDING_MIN_ENGAGEMENT_SCORE}
  )
  SELECT p.*, rp.unique_tenants, rp.weighted_score,
         rp.exposure_count, rp.engagement_rate
    FROM properties p
    JOIN ranked_properties rp ON rp.property_id = p.id
   WHERE ${filters}
   ORDER BY rp.engagement_rate DESC, rp.weighted_score DESC,
            rp.unique_tenants DESC, p.published_at DESC NULLS LAST, p.id
   LIMIT $${limitParameter}`;
}
//# sourceMappingURL=discovery_rules.js.map