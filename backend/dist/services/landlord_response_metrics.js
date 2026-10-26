import { query } from '../db.js';
function positiveIntegerSetting(name, fallback) {
    const parsed = Number.parseInt(process.env[name] ?? '', 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}
const responseThresholds = {
    minimumSample: positiveIntegerSetting('LANDLORD_RESPONSE_MIN_SAMPLE', 3),
    lightningFastMinutes: positiveIntegerSetting('LANDLORD_RESPONSE_LIGHTNING_FAST_MINUTES', 5),
    quickResponderMinutes: positiveIntegerSetting('LANDLORD_RESPONSE_QUICK_MINUTES', 15),
    needsImprovementMinutes: positiveIntegerSetting('LANDLORD_RESPONSE_NEEDS_IMPROVEMENT_MINUTES', 60),
    unansweredLabelSample: positiveIntegerSetting('LANDLORD_RESPONSE_UNANSWERED_LABEL_MIN_SAMPLE', 5),
    improvementThresholdPercent: positiveIntegerSetting('LANDLORD_RESPONSE_IMPROVEMENT_THRESHOLD_PERCENT', 20),
    conversionMinimumSample: positiveIntegerSetting('LANDLORD_RESPONSE_CONVERSION_MIN_SAMPLE', 10),
};
function metricNumber(value) {
    const parsed = typeof value === 'number' ? value : Number(value ?? 0);
    return Number.isFinite(parsed) ? parsed : 0;
}
export function classifyResponsePerformance(input) {
    const { totalValidInquiries, answeredInquiries, averageFirstResponseMinutes, previousAverageFirstResponseMinutes, previousAnsweredInquiries, } = input;
    if (totalValidInquiries < responseThresholds.minimumSample ||
        answeredInquiries < responseThresholds.minimumSample ||
        averageFirstResponseMinutes === null) {
        return 'response_activity_building';
    }
    if (totalValidInquiries >= responseThresholds.unansweredLabelSample &&
        totalValidInquiries - answeredInquiries >= totalValidInquiries / 2) {
        return 'needs_improvement';
    }
    if (averageFirstResponseMinutes <= responseThresholds.lightningFastMinutes) {
        return 'lightning_fast';
    }
    if (averageFirstResponseMinutes <= responseThresholds.quickResponderMinutes) {
        return 'quick_responder';
    }
    if (totalValidInquiries >= responseThresholds.unansweredLabelSample &&
        averageFirstResponseMinutes >= responseThresholds.needsImprovementMinutes) {
        return 'needs_improvement';
    }
    if (previousAnsweredInquiries >= 3 &&
        previousAverageFirstResponseMinutes !== null &&
        previousAverageFirstResponseMinutes > 0 &&
        (previousAverageFirstResponseMinutes - averageFirstResponseMinutes) /
            previousAverageFirstResponseMinutes >=
            responseThresholds.improvementThresholdPercent / 100) {
        return 'getting_faster';
    }
    return 'steady_responder';
}
export async function getLandlordResponseMetrics(landlordId, propertyId) {
    const result = await query(`WITH property_conversations AS (
       SELECT mc.id, mc.property_id, p.landlord_id
       FROM message_conversations mc
       JOIN properties p ON p.id = mc.property_id
       WHERE p.landlord_id = $1
         AND mc.context_type = 'property'
         AND mc.created_at >= now() - INTERVAL '60 days'
         AND ($2::uuid IS NULL OR mc.property_id = $2::uuid)
     ), first_inquiries AS (
       SELECT pc.id AS conversation_id,
              pc.property_id,
              pc.landlord_id,
              tenant_message.from_user_id AS tenant_id,
              tenant_message.created_at AS inquiry_at
       FROM property_conversations pc
       JOIN LATERAL (
         SELECT m.from_user_id, m.created_at
         FROM messages m
         JOIN users tenant ON tenant.id = m.from_user_id
         WHERE m.conversation_id = pc.id
           AND m.from_user_id <> pc.landlord_id
           AND btrim(m.text) <> ''
           AND (tenant.role = 'tenant' OR 'tenant' = ANY(tenant.roles))
         ORDER BY m.created_at ASC, m.id ASC
         LIMIT 1
       ) tenant_message ON true
     ), inquiries_with_responses AS (
       SELECT i.*,
              landlord_message.first_response_at,
              CASE WHEN landlord_message.first_response_at IS NULL THEN NULL
                   ELSE EXTRACT(EPOCH FROM (
                     landlord_message.first_response_at - i.inquiry_at
                   )) / 60.0
              END AS response_minutes
       FROM first_inquiries i
       LEFT JOIN LATERAL (
         SELECT m.created_at AS first_response_at
         FROM messages m
         WHERE m.conversation_id = i.conversation_id
           AND m.from_user_id = i.landlord_id
           AND m.created_at > i.inquiry_at
           AND btrim(m.text) <> ''
         ORDER BY m.created_at ASC, m.id ASC
         LIMIT 1
       ) landlord_message ON true
     )
     SELECT
       COUNT(*) FILTER (
         WHERE inquiry_at >= now() - INTERVAL '30 days'
           AND inquiry_at <= now() - INTERVAL '12 hours'
       )::int AS total_valid_inquiries,
       COUNT(*) FILTER (
         WHERE inquiry_at >= now() - INTERVAL '30 days'
           AND inquiry_at <= now() - INTERVAL '12 hours'
           AND first_response_at IS NOT NULL
       )::int AS answered_inquiries,
       AVG(response_minutes) FILTER (
         WHERE inquiry_at >= now() - INTERVAL '30 days'
           AND inquiry_at <= now() - INTERVAL '12 hours'
           AND first_response_at IS NOT NULL
       ) AS average_first_response_minutes,
       MAX(first_response_at) FILTER (
         WHERE inquiry_at >= now() - INTERVAL '30 days'
           AND inquiry_at <= now() - INTERVAL '12 hours'
       ) AS last_response_at,
       COUNT(*) FILTER (
         WHERE inquiry_at >= now() - INTERVAL '60 days'
           AND inquiry_at < now() - INTERVAL '30 days'
           AND inquiry_at <= now() - INTERVAL '12 hours'
       )::int AS previous_total_inquiries,
       COUNT(*) FILTER (
         WHERE inquiry_at >= now() - INTERVAL '60 days'
           AND inquiry_at < now() - INTERVAL '30 days'
           AND inquiry_at <= now() - INTERVAL '12 hours'
           AND first_response_at IS NOT NULL
       )::int AS previous_answered_inquiries,
       AVG(response_minutes) FILTER (
         WHERE inquiry_at >= now() - INTERVAL '60 days'
           AND inquiry_at < now() - INTERVAL '30 days'
           AND inquiry_at <= now() - INTERVAL '12 hours'
           AND first_response_at IS NOT NULL
       ) AS previous_average_response_minutes,
       COUNT(*) FILTER (
         WHERE inquiry_at >= now() - INTERVAL '60 days'
           AND inquiry_at <= now() - INTERVAL '30 days'
           AND response_minutes <= 15
       )::int AS fast_conversion_sample,
       COUNT(*) FILTER (
         WHERE inquiry_at >= now() - INTERVAL '60 days'
           AND inquiry_at <= now() - INTERVAL '30 days'
           AND response_minutes <= 15
           AND EXISTS (
             SELECT 1 FROM bookings b
             WHERE b.property_id = inquiries_with_responses.property_id
               AND b.tenant_id = inquiries_with_responses.tenant_id
               AND b.created_at >= inquiries_with_responses.inquiry_at
               AND b.created_at <= inquiries_with_responses.inquiry_at + INTERVAL '30 days'
               AND b.status IN ('confirmed', 'completed')
           )
       )::int AS fast_booking_count,
       COUNT(*) FILTER (
         WHERE inquiry_at >= now() - INTERVAL '60 days'
           AND inquiry_at <= now() - INTERVAL '30 days'
           AND (response_minutes > 15 OR response_minutes IS NULL)
       )::int AS slow_conversion_sample,
       COUNT(*) FILTER (
         WHERE inquiry_at >= now() - INTERVAL '60 days'
           AND inquiry_at <= now() - INTERVAL '30 days'
           AND (response_minutes > 15 OR response_minutes IS NULL)
           AND EXISTS (
             SELECT 1 FROM bookings b
             WHERE b.property_id = inquiries_with_responses.property_id
               AND b.tenant_id = inquiries_with_responses.tenant_id
               AND b.created_at >= inquiries_with_responses.inquiry_at
               AND b.created_at <= inquiries_with_responses.inquiry_at + INTERVAL '30 days'
               AND b.status IN ('confirmed', 'completed')
           )
       )::int AS slow_booking_count
     FROM inquiries_with_responses`, [landlordId, propertyId ?? null]);
    const row = result.rows[0];
    const totalValidInquiries = metricNumber(row?.total_valid_inquiries);
    const answeredInquiries = metricNumber(row?.answered_inquiries);
    const unansweredInquiries = Math.max(0, totalValidInquiries - answeredInquiries);
    const average = row?.average_first_response_minutes == null
        ? null
        : metricNumber(row.average_first_response_minutes);
    const previousAverage = row?.previous_average_response_minutes == null
        ? null
        : metricNumber(row.previous_average_response_minutes);
    const previousAnsweredInquiries = metricNumber(row?.previous_answered_inquiries);
    const responseRate = totalValidInquiries === 0
        ? null
        : Math.round((answeredInquiries / totalValidInquiries) * 100);
    const trendPercentage = average !== null && previousAverage !== null && previousAverage > 0
        ? Math.round(((previousAverage - average) / previousAverage) * 100)
        : null;
    const fastSample = metricNumber(row?.fast_conversion_sample);
    const slowSample = metricNumber(row?.slow_conversion_sample);
    const fastBookings = metricNumber(row?.fast_booking_count);
    const slowBookings = metricNumber(row?.slow_booking_count);
    return {
        averageFirstResponseMinutes: average === null ? null : Math.round(average),
        responseRate,
        totalValidInquiries,
        answeredInquiries,
        unansweredInquiries,
        missedInquiries: unansweredInquiries,
        performanceLabel: classifyResponsePerformance({
            totalValidInquiries,
            answeredInquiries,
            averageFirstResponseMinutes: average,
            previousAverageFirstResponseMinutes: previousAverage,
            previousAnsweredInquiries,
        }),
        trendPercentage,
        lastResponseAt: row?.last_response_at ?? null,
        sampleSize: totalValidInquiries,
        calculationPeriodDays: 30,
        bookingConversion: fastSample >= responseThresholds.conversionMinimumSample &&
            slowSample >= responseThresholds.conversionMinimumSample
            ? {
                calculationPeriodDays: 60,
                outcomeWindowDays: 30,
                fastResponse: {
                    sampleSize: fastSample,
                    confirmedBookings: fastBookings,
                    conversionRate: Math.round((fastBookings / fastSample) * 100),
                },
                slowerOrUnanswered: {
                    sampleSize: slowSample,
                    confirmedBookings: slowBookings,
                    conversionRate: Math.round((slowBookings / slowSample) * 100),
                },
            }
            : null,
    };
}
//# sourceMappingURL=landlord_response_metrics.js.map