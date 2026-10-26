import { Router } from 'express';
import { pool, query } from '../db.js';
import { authorize, requireAuth } from '../middleware/auth.js';
import { calculateRate, calculateGrowthPercent, calculateOccupancyRate, formatGrowthPercent, } from '../services/landlord_metrics.js';
import { generateLandlordRecommendations } from '../services/landlord_recommendations.js';
import { getLandlordResponseMetrics } from '../services/landlord_response_metrics.js';
const router = Router();
router.post('/impression', requireAuth, authorize('tenant'), async (req, res, next) => {
    const propertyId = typeof req.body?.propertyId === 'string'
        ? req.body.propertyId.trim()
        : '';
    const uuidV4ish = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$/;
    if (!uuidV4ish.test(propertyId)) {
        return res.status(400).json({ error: 'Invalid propertyId.' });
    }
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const property = await client.query(`SELECT landlord_id FROM properties
        WHERE id = $1 AND COALESCE(status, 'pending_review') = 'approved'
        LIMIT 1`, [propertyId]);
        if (property.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Property not found.' });
        }
        if (property.rows[0].landlord_id === req.auth.id) {
            await client.query('COMMIT');
            return res.json({ ok: true, ignored: true, reason: 'landlord_own_property' });
        }
        await client.query(`SELECT pg_advisory_xact_lock(hashtext($1), hashtext($2))`, [propertyId, `${req.auth.id}:property_impression`]);
        const prior = await client.query(`SELECT 1 FROM engagement_events
        WHERE user_id = $1 AND property_id = $2
          AND event_type = 'property_impression'
          AND created_at >= CURRENT_DATE
        LIMIT 1`, [req.auth.id, propertyId]);
        if (prior.rows.length > 0) {
            await client.query('COMMIT');
            return res.json({ ok: true, ignored: true, reason: 'duplicate_impression_today' });
        }
        await client.query(`INSERT INTO engagement_events (user_id, property_id, event_type, metadata)
       VALUES ($1, $2, 'property_impression', $3::jsonb)`, [req.auth.id, propertyId, JSON.stringify({ source: 'visible_property_card' })]);
        await client.query(`INSERT INTO property_analytics (property_id, impressions, updated_at)
       VALUES ($1, 1, NOW())
       ON CONFLICT (property_id) DO UPDATE
         SET impressions = property_analytics.impressions + 1,
             updated_at = NOW()`, [propertyId]);
        await client.query('COMMIT');
        return res.status(201).json({ ok: true, eventType: 'property_impression' });
    }
    catch (error) {
        await client.query('ROLLBACK');
        return next(error);
    }
    finally {
        client.release();
    }
});
const EVENT_WEIGHTS = {
    property_view: 1,
    property_detail_view: 1,
    property_click: 2,
    property_save: 5,
    property_share: 3,
    chat_started: 8,
    booking_requested: 15,
    booking_confirmed: 25,
    booking_completed: 50,
};
const METRIC_COLUMNS = {
    property_view: 'views',
    property_detail_view: 'views',
    property_click: 'clicks',
    property_save: 'saves',
    property_share: 'shares',
    chat_started: 'chats',
    booking_requested: 'booking_requested',
    booking_confirmed: 'bookings_confirmed',
    booking_completed: 'bookings_completed',
};
function getTimeWindow(filter) {
    if (filter === 'Last 28 Days')
        return '28 days';
    return '7 days';
}
function toNumber(value) {
    // Postgres aggregation functions (SUM, COUNT) often return strings to preserve precision
    const n = typeof value === 'string' ? parseFloat(value) : (typeof value === 'number' ? value : Number(value ?? 0));
    return Number.isFinite(n) ? n : 0;
}
router.post('/track', requireAuth, authorize('tenant'), async (req, res, next) => {
    if (req.auth?.role?.toLowerCase() !== 'tenant') {
        return res.status(403).json({ error: 'Only tenant portal interactions are countable.' });
    }
    const logPrefix = `[AnalyticsTrack]`;
    const { eventType, propertyId } = req.body;
    console.log(`${logPrefix} start userId=${req.auth?.id} eventType=${eventType} propertyId=${propertyId}`);
    // Validate propertyId early to avoid UUID cast errors from garbage values.
    const propertyIdStr = typeof propertyId === 'string' ? propertyId : '';
    const uuidV4ish = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$/;
    if (!uuidV4ish.test(propertyIdStr)) {
        console.warn(`${logPrefix} invalid propertyId. Ignoring event. propertyId=${propertyIdStr}`);
        return res.status(400).json({ error: 'Invalid propertyId' });
    }
    const client = await pool.connect();
    try {
        const { eventType, propertyId, sessionId, metadata = {}, } = req.body;
        const userId = req.auth?.id;
        if (!eventType || !propertyId) {
            return res.status(400).json({ error: 'eventType and propertyId are required.' });
        }
        const supportedEvent = Object.prototype.hasOwnProperty.call(EVENT_WEIGHTS, eventType);
        if (!supportedEvent) {
            return res.status(400).json({ error: 'Unsupported analytics event.' });
        }
        const isViewEvent = eventType === 'property_view' || eventType === 'property_detail_view';
        const propertyExists = await client.query('SELECT landlord_id FROM properties WHERE id = $1 LIMIT 1', [propertyId]);
        if (propertyExists.rows.length === 0) {
            return res.status(404).json({ error: 'Property not found.' });
        }
        if (userId && userId === propertyExists.rows[0].landlord_id) {
            // Don't track interactions if the landlord is viewing their own property
            return res.status(200).json({ ok: true, ignored: true, reason: 'landlord_own_property' });
        }
        await client.query('BEGIN');
        try {
            const isSaveEvent = eventType === 'property_save';
            const isImpressionEvent = eventType.includes('impression');
            let isFirstEverAction = true;
            const checkVal = userId || sessionId;
            if (checkVal) {
                const checkQuery = userId
                    ? `SELECT 1 FROM engagement_events WHERE user_id = $1 AND property_id = $2 AND event_type = $3 LIMIT 1`
                    : `SELECT 1 FROM engagement_events WHERE session_id = $1 AND property_id = $2 AND event_type = $3 LIMIT 1`;
                const priorCheck = await client.query(checkQuery, [checkVal, propertyId, eventType]);
                isFirstEverAction = priorCheck.rows.length === 0;
            }
            if (isViewEvent) {
                // One view per property per day
                const uniqueView = await client.query(`INSERT INTO property_unique_views (property_id, user_id, viewed_date)
           VALUES ($1, $2, CURRENT_DATE)
           ON CONFLICT (property_id, user_id, viewed_date) DO NOTHING
           RETURNING property_id`, [propertyId, userId]);
                if (uniqueView.rows.length === 0) {
                    await client.query('ROLLBACK');
                    return res.status(200).json({ ok: true, ignored: true, reason: 'duplicate_view_today' });
                }
            }
            else if (isImpressionEvent) {
                if (checkVal) {
                    const checkQuery = userId
                        ? `SELECT 1 FROM engagement_events WHERE user_id = $1 AND property_id = $2 AND event_type = $3 AND created_at >= CURRENT_DATE LIMIT 1`
                        : `SELECT 1 FROM engagement_events WHERE session_id = $1 AND property_id = $2 AND event_type = $3 AND created_at >= CURRENT_DATE LIMIT 1`;
                    const prior = await client.query(checkQuery, [checkVal, propertyId, eventType]);
                    if (prior.rows.length > 0) {
                        await client.query('ROLLBACK');
                        return res.status(200).json({ ok: true, ignored: true, reason: 'duplicate_impression_today' });
                    }
                }
            }
            else if (isSaveEvent) {
                if (!isFirstEverAction) {
                    await client.query('ROLLBACK');
                    return res.status(200).json({ ok: true, ignored: true, reason: 'already_saved' });
                }
            }
            await client.query(`INSERT INTO engagement_events (user_id, property_id, event_type, session_id, metadata, created_at)
         VALUES ($1, $2, $3, $4, $5, NOW())`, [userId, propertyId, eventType, sessionId ?? null, metadata]);
            const weight = EVENT_WEIGHTS[eventType] ?? 0;
            const score = weight * (isFirstEverAction ? 1.5 : 1);
            const column = METRIC_COLUMNS[eventType];
            const uniqueInc = (isViewEvent && isFirstEverAction) ? 1 : 0;
            const metricInc = 1;
            await client.query(`INSERT INTO property_analytics (property_id, views, unique_views, impressions, clicks, saves, shares, chats, booking_requested, bookings_confirmed, bookings_completed, engagement_score, last_event_at, updated_at)
         VALUES ($1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NOW(), NOW())
         ON CONFLICT (property_id) DO NOTHING`, [propertyId]);
            await client.query(`UPDATE property_analytics
         SET ${column ? `${column} = property_analytics.${column} + $4,` : ''}
           unique_views = property_analytics.unique_views + $2,
           engagement_score = COALESCE(property_analytics.engagement_score, 0) + $3,
           last_event_at = NOW(),
           updated_at = NOW()
       WHERE property_id = $1`, [propertyId, uniqueInc, score, metricInc]);
            await client.query('COMMIT');
            res.status(201).json({ ok: true, eventType, uniqueInc });
        }
        catch (error) {
            await client.query('ROLLBACK');
            throw error;
        }
    }
    catch (error) {
        next(error);
    }
    finally {
        client.release();
    }
});
router.get('/stats/:propertyId', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
    try {
        const { propertyId } = req.params;
        const result = await query(`SELECT pa.*,
              p.title,
              p.image_url,
              p.landlord_id,
              (SELECT COUNT(*) FROM property_unique_views puv
               WHERE puv.property_id = p.id) AS counted_views
       FROM property_analytics pa
       JOIN properties p ON p.id = pa.property_id
       WHERE pa.property_id = $1`, [propertyId]);
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'Analytics not found for property.' });
        }
        const row = result.rows[0];
        // Verify landlord ownership
        if (row.landlord_id !== req.auth?.id) {
            return res.status(403).json({ error: 'You are not authorized to view analytics for this property.' });
        }
        const views = toNumber(row.counted_views);
        const clicks = toNumber(row.clicks);
        const impressions = toNumber(row.impressions);
        const saves = toNumber(row.saves);
        const shares = toNumber(row.shares);
        res.json({
            propertyId,
            title: row.title,
            imageUrl: row.image_url,
            landlordId: row.landlord_id,
            stats: {
                views,
                uniqueViews: views,
                impressions,
                clicks,
                saves,
                shares,
                chats: toNumber(row.chats),
                bookingRequested: toNumber(row.booking_requested),
                bookingsConfirmed: toNumber(row.bookings_confirmed),
                bookingsCompleted: toNumber(row.bookings_completed),
                engagementScore: toNumber(row.engagement_score),
                velocityScore: toNumber(row.velocity_score),
                avgTimeSpentMs: toNumber(row.avg_time_spent_ms),
                conversionRate: views > 0 ? (toNumber(row.booking_requested) / views) * 100 : 0,
                ctr: impressions > 0 ? (clicks / impressions) * 100 : 0,
                engagementRate: views > 0 ? ((saves + clicks + shares) / views) * 100 : 0,
            },
        });
    }
    catch (error) {
        next(error);
    }
});
router.get('/landlord-dashboard', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
    try {
        const period = String(req.query.period ?? '7d');
        if (!['7d', '28d', '90d'].includes(period)) {
            return res.status(400).json({ error: 'period must be 7d, 28d, or 90d.' });
        }
        const days = period === '90d' ? 90 : period === '28d' ? 28 : 7;
        const landlordId = req.auth?.id;
        const [propsRes, viewsRes, prevViewsRes, enquiriesRes, prevEnquiriesRes, conversionRes, pendingBookingsRes, responseMetrics, chartRes, activityRes, recommendations] = await Promise.all([
            // 1. Property breakdown
            query(`SELECT 
           COUNT(*)::int AS total,
           COUNT(*) FILTER (WHERE status = 'approved')::int AS published,
           COUNT(*) FILTER (WHERE status = 'pending_review')::int AS pending,
           COUNT(*) FILTER (WHERE status = 'draft')::int AS draft,
           COUNT(*) FILTER (WHERE availability_status = 'rented')::int AS rented,
           COUNT(*) FILTER (WHERE availability_status = 'unavailable')::int AS unavailable
         FROM properties
         WHERE landlord_id = $1`, [landlordId]),
            // 2. Views in period & unique viewers
            query(`SELECT 
           COUNT(*)::int AS total_views,
           COUNT(DISTINCT puv.user_id)::int AS unique_viewers
         FROM property_unique_views puv
         JOIN properties p ON p.id = puv.property_id
         WHERE p.landlord_id = $1
           AND puv.viewed_date >= CURRENT_DATE - ($2::int - 1)`, [landlordId, days]),
            // 3. Views in previous period for growth
            query(`SELECT COUNT(*)::int AS total_views
         FROM property_unique_views puv
         JOIN properties p ON p.id = puv.property_id
         WHERE p.landlord_id = $1
           AND puv.viewed_date >= CURRENT_DATE - ($2::int * 2 - 1)
           AND puv.viewed_date < CURRENT_DATE - ($2::int - 1)`, [landlordId, days]),
            // Property-linked conversations do not prove a lead was qualified.
            query(`SELECT 
           COUNT(DISTINCT mc.id)::int AS total_enquiries,
           COUNT(DISTINCT CASE WHEN mc.participant_one_id = p.landlord_id THEN mc.participant_two_id ELSE mc.participant_one_id END)::int AS unique_enquirers
         FROM message_conversations mc
         JOIN properties p ON p.id = mc.property_id
         WHERE p.landlord_id = $1
           AND mc.context_type = 'property'
           AND mc.created_at >= CURRENT_DATE - ($2::int - 1)`, [landlordId, days]),
            // 5. Previous period enquiries
            query(`SELECT COUNT(DISTINCT mc.id)::int AS total_enquiries
         FROM message_conversations mc
         JOIN properties p ON p.id = mc.property_id
         WHERE p.landlord_id = $1
           AND mc.context_type = 'property'
           AND mc.created_at >= CURRENT_DATE - ($2::int * 2 - 1)
           AND mc.created_at < CURRENT_DATE - ($2::int - 1)`, [landlordId, days]),
            // Timestamped tenant views allow us to require the view to precede the
            // property-linked conversation in the same reporting window.
            query(`SELECT
           COUNT(DISTINCT (view_event.property_id, view_event.user_id))::int AS eligible_viewers,
           COUNT(DISTINCT (view_event.property_id, view_event.user_id)) FILTER (
             WHERE mc.id IS NOT NULL
           )::int AS converted_pairs
         FROM engagement_events view_event
         JOIN properties p ON p.id = view_event.property_id
         LEFT JOIN message_conversations mc
           ON mc.property_id = view_event.property_id
          AND mc.context_type = 'property'
          AND mc.created_at >= CURRENT_DATE - ($2::int - 1)
          AND mc.created_at < CURRENT_DATE + 1
          AND mc.created_at >= view_event.created_at
          AND (CASE WHEN mc.participant_one_id = p.landlord_id
                    THEN mc.participant_two_id ELSE mc.participant_one_id END) = view_event.user_id
         WHERE p.landlord_id = $1
           AND view_event.user_id IS NOT NULL
           AND view_event.event_type IN ('property_view', 'property_detail_view')
           AND view_event.created_at >= CURRENT_DATE - ($2::int - 1)
           AND view_event.created_at < CURRENT_DATE + 1`, [landlordId, days]),
            // 7. Pending bookings
            query(`SELECT COUNT(*)::int AS pending_count
         FROM bookings
         WHERE landlord_id = $1
           AND status = 'pending'
           AND check_out_date >= CURRENT_DATE`, [landlordId]),
            getLandlordResponseMetrics(landlordId),
            // 9. Chart data
            query(`SELECT puv.viewed_date AS day, COUNT(*)::int AS total
         FROM property_unique_views puv
         JOIN properties p ON p.id = puv.property_id
         WHERE p.landlord_id = $1
           AND puv.viewed_date >= CURRENT_DATE - ($2::int - 1)
         GROUP BY puv.viewed_date
         ORDER BY day ASC`, [landlordId, days]),
            query(`SELECT
           (SELECT COUNT(*)::int
              FROM engagement_events e
              JOIN properties p ON p.id = e.property_id
             WHERE p.landlord_id = $1
               AND e.event_type = 'property_impression'
               AND e.created_at >= CURRENT_DATE - ($2::int - 1)
               AND e.created_at < CURRENT_DATE + 1) AS impressions,
           (SELECT COUNT(*)::int
              FROM property_unique_views v
              JOIN properties p ON p.id = v.property_id
             WHERE p.landlord_id = $1
               AND v.viewed_date >= CURRENT_DATE - ($2::int - 1)
               AND v.viewed_date <= CURRENT_DATE) AS detail_views,
           (SELECT COUNT(DISTINCT (e.property_id, e.user_id))::int
              FROM engagement_events e
              JOIN properties p ON p.id = e.property_id
             WHERE p.landlord_id = $1
               AND e.user_id IS NOT NULL
               AND e.event_type IN ('property_save', 'property_share', 'property_click')
               AND e.created_at >= CURRENT_DATE - ($2::int - 1)
               AND e.created_at < CURRENT_DATE + 1) AS engaged_pairs,
           (SELECT COUNT(DISTINCT (e.property_id, e.user_id))::int
              FROM engagement_events e
              JOIN properties p ON p.id = e.property_id
             WHERE p.landlord_id = $1
               AND e.user_id IS NOT NULL
               AND e.event_type = 'property_save'
               AND e.created_at >= CURRENT_DATE - ($2::int - 1)
               AND e.created_at < CURRENT_DATE + 1) AS saves,
           (SELECT COUNT(DISTINCT (e.property_id, e.user_id))::int
              FROM engagement_events e
              JOIN properties p ON p.id = e.property_id
             WHERE p.landlord_id = $1
               AND e.user_id IS NOT NULL
               AND e.event_type = 'property_share'
               AND e.created_at >= CURRENT_DATE - ($2::int - 1)
               AND e.created_at < CURRENT_DATE + 1) AS shares,
           (SELECT COUNT(DISTINCT (e.property_id, e.user_id))::int
              FROM engagement_events e
              JOIN properties p ON p.id = e.property_id
             WHERE p.landlord_id = $1
               AND e.user_id IS NOT NULL
               AND e.event_type = 'property_click'
               AND e.created_at >= CURRENT_DATE - ($2::int - 1)
               AND e.created_at < CURRENT_DATE + 1) AS clicks,
           (SELECT COUNT(DISTINCT mc.id)::int
              FROM message_conversations mc
              JOIN properties p ON p.id = mc.property_id
             WHERE p.landlord_id = $1
               AND mc.context_type = 'property'
               AND mc.created_at >= CURRENT_DATE - ($2::int - 1)
               AND mc.created_at < CURRENT_DATE + 1) AS conversations,
           (SELECT COUNT(*)::int
              FROM bookings b
             WHERE b.landlord_id = $1
               AND b.created_at >= CURRENT_DATE - ($2::int - 1)
               AND b.created_at < CURRENT_DATE + 1) AS booking_requests,
           (SELECT COUNT(*)::int
              FROM bookings b
             WHERE b.landlord_id = $1
               AND b.status IN ('confirmed', 'completed')
               AND b.created_at >= CURRENT_DATE - ($2::int - 1)
               AND b.created_at < CURRENT_DATE + 1) AS confirmed_bookings`, [landlordId, days]),
            // 10. Recommendations
            generateLandlordRecommendations(landlordId)
        ]);
        const propsRow = propsRes.rows[0] ?? {};
        const viewsRow = viewsRes.rows[0] ?? {};
        const prevViewsRow = prevViewsRes.rows[0] ?? {};
        const enquiriesRow = enquiriesRes.rows[0] ?? {};
        const prevEnquiriesRow = prevEnquiriesRes.rows[0] ?? {};
        const conversionRow = conversionRes.rows[0] ?? {};
        const pendingBookingsRow = pendingBookingsRes.rows[0] ?? {};
        const activityRow = activityRes.rows[0] ?? {};
        const currViews = Number(viewsRow.total_views ?? 0);
        const prevViews = Number(prevViewsRow.total_views ?? 0);
        const uniqueViewers = Number(viewsRow.unique_viewers ?? 0);
        let viewsGrowth = '+0%';
        if (prevViews > 0) {
            const g = ((currViews - prevViews) / prevViews) * 100;
            viewsGrowth = (g > 0 ? '+' : '') + g.toFixed(1) + '%';
        }
        else if (currViews > 0) {
            viewsGrowth = '+100%';
        }
        const currEnquiries = Number(enquiriesRow.total_enquiries ?? 0);
        const uniqueEnquirers = Number(enquiriesRow.unique_enquirers ?? 0);
        const prevEnquiries = Number(prevEnquiriesRow.total_enquiries ?? 0);
        let enquiriesGrowth = '+0%';
        if (prevEnquiries > 0) {
            const eg = ((currEnquiries - prevEnquiries) / prevEnquiries) * 100;
            enquiriesGrowth = (eg > 0 ? '+' : '') + eg.toFixed(1) + '%';
        }
        else if (currEnquiries > 0) {
            enquiriesGrowth = '+100%';
        }
        const repliedCount = responseMetrics.answeredInquiries;
        const totalConvs = responseMetrics.totalValidInquiries;
        const responseRatePercent = responseMetrics.responseRate ?? 0;
        const eligibleViewers = Number(conversionRow.eligible_viewers ?? 0);
        const convertedPairs = Number(conversionRow.converted_pairs ?? 0);
        const conversionPercent = calculateRate(convertedPairs, eligibleViewers);
        const impressionCount = Number(activityRow.impressions ?? 0);
        const clickCount = Number(activityRow.clicks ?? 0);
        const clickThroughRate = calculateRate(clickCount, impressionCount);
        const dateMap = new Map();
        chartRes.rows.forEach((r) => {
            const d = new Date(r.day);
            const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
            dateMap.set(key, Number(r.total ?? 0));
        });
        const seriesData = [];
        for (let i = 0; i < days; i++) {
            const d = new Date();
            d.setDate(d.getDate() - (days - 1 - i));
            const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
            seriesData.push(dateMap.get(key) || 0);
        }
        res.json({
            period: { days, filter: period },
            kpis: {
                properties: {
                    total: Number(propsRow.total ?? 0),
                    published: Number(propsRow.published ?? 0),
                    pending: Number(propsRow.pending ?? 0),
                    draft: Number(propsRow.draft ?? 0),
                    rented: Number(propsRow.rented ?? 0),
                    unavailable: Number(propsRow.unavailable ?? 0),
                },
                views: {
                    total: currViews,
                    uniqueViewers,
                    growth: viewsGrowth,
                },
                enquiries: {
                    total: currEnquiries,
                    uniqueTenants: uniqueEnquirers,
                    unanswered: responseMetrics.unansweredInquiries,
                    growth: enquiriesGrowth,
                },
                pendingBookings: {
                    count: Number(pendingBookingsRow.pending_count ?? 0),
                },
                responseRate: {
                    responded: repliedCount,
                    total: totalConvs,
                    percentage: responseRatePercent,
                },
                conversion: {
                    eligibleViewers,
                    convertedPairs,
                    percentage: conversionPercent,
                },
            },
            metrics: {
                uniqueViewers,
                saves: Number(activityRow.saves ?? 0),
                shares: Number(activityRow.shares ?? 0),
                avgCtr: clickThroughRate,
            },
            responseMetrics,
            chartData: seriesData,
            funnel: [
                { label: 'Listing impressions', value: Number(activityRow.impressions ?? 0) },
                { label: 'Property detail views', value: Number(activityRow.detail_views ?? 0) },
                { label: 'Meaningful engagement pairs', value: Number(activityRow.engaged_pairs ?? 0) },
                { label: 'Property-linked conversations', value: Number(activityRow.conversations ?? 0) },
                { label: 'Booking requests', value: Number(activityRow.booking_requests ?? 0) },
                { label: 'Confirmed or completed bookings', value: Number(activityRow.confirmed_bookings ?? 0) },
            ],
            funnelDefinition: 'Counts use the selected reporting period; stages are not a sequential user journey.',
            recommendations,
        });
    }
    catch (error) {
        next(error);
    }
});
router.get('/landlord-property-performance', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
    try {
        const period = String(req.query.period ?? '7d');
        if (!['7d', '28d', '90d'].includes(period)) {
            return res.status(400).json({ error: 'period must be 7d, 28d, or 90d.' });
        }
        const days = period === '90d' ? 90 : period === '28d' ? 28 : 7;
        const search = typeof req.query.search === 'string'
            ? req.query.search.trim().slice(0, 100)
            : '';
        const parsedLimit = Number.parseInt(String(req.query.limit ?? '15'), 10);
        const parsedOffset = Number.parseInt(String(req.query.offset ?? '0'), 10);
        const limit = Number.isFinite(parsedLimit) ? Math.min(50, Math.max(1, parsedLimit)) : 15;
        const offset = Number.isFinite(parsedOffset) ? Math.min(100000, Math.max(0, parsedOffset)) : 0;
        const result = await query(`WITH property_scope AS MATERIALIZED (
         SELECT p.id, p.title, p.image_url, p.city,
                COALESCE(NULLIF(p.address, ''), NULLIF(p.town, ''),
                         NULLIF(p.city, ''), NULLIF(p.county, ''), '') AS location,
                p.price, p.status, p.availability_status,
                COUNT(*) OVER()::int AS total_count
         FROM properties p
         WHERE p.landlord_id = $1
           AND ($3::text = '' OR p.title ILIKE '%' || $3 || '%'
                OR COALESCE(p.city, '') ILIKE '%' || $3 || '%'
                OR COALESCE(p.address, '') ILIKE '%' || $3 || '%')
       ), views AS (
         SELECT puv.property_id,
                COUNT(*) FILTER (
                  WHERE puv.viewed_date >= CURRENT_DATE - ($2::int - 1)
                )::int AS views,
                COUNT(DISTINCT puv.user_id) FILTER (
                  WHERE puv.viewed_date >= CURRENT_DATE - ($2::int - 1)
                )::int AS unique_viewers,
                COUNT(*) FILTER (
                  WHERE puv.viewed_date < CURRENT_DATE - ($2::int - 1)
                )::int AS previous_views
         FROM property_unique_views puv
         JOIN property_scope p ON p.id = puv.property_id
         WHERE puv.viewed_date >= CURRENT_DATE - ($2::int * 2 - 1)
           AND puv.viewed_date <= CURRENT_DATE
         GROUP BY puv.property_id
       ), impressions AS (
         SELECT e.property_id,
                COUNT(*) FILTER (
                  WHERE e.created_at >= CURRENT_DATE - ($2::int - 1)
                )::int AS impressions
         FROM engagement_events e
         JOIN property_scope p ON p.id = e.property_id
         WHERE e.event_type = 'property_impression'
           AND e.created_at >= CURRENT_DATE - ($2::int - 1)
           AND e.created_at < CURRENT_DATE + 1
         GROUP BY e.property_id
       ), view_cohorts AS MATERIALIZED (
         SELECT DISTINCT puv.property_id, puv.user_id, puv.viewed_date,
                CASE
                  WHEN puv.viewed_date >= CURRENT_DATE - ($2::int - 1)
                    THEN 'current'
                  ELSE 'previous'
                END AS cohort
         FROM property_unique_views puv
         JOIN property_scope p ON p.id = puv.property_id
         WHERE puv.user_id IS NOT NULL
           AND puv.viewed_date >= CURRENT_DATE - ($2::int * 2 - 1)
           AND puv.viewed_date <= CURRENT_DATE
       ), eligible_engagement AS MATERIALIZED (
         SELECT DISTINCT e.property_id, e.user_id, e.event_type, e.created_at,
                v.cohort
         FROM engagement_events e
         JOIN property_scope p ON p.id = e.property_id
         JOIN view_cohorts v
           ON v.property_id = e.property_id
          AND v.user_id = e.user_id
          AND v.viewed_date::timestamptz <= e.created_at
          AND v.cohort = CASE
            WHEN e.created_at >= CURRENT_DATE - ($2::int - 1)
              THEN 'current'
            ELSE 'previous'
          END
         WHERE e.user_id IS NOT NULL
           AND e.event_type IN ('property_click', 'property_save', 'property_share')
           AND e.created_at >= CURRENT_DATE - ($2::int * 2 - 1)
           AND e.created_at < CURRENT_DATE + 1
       ), engagement AS (
         SELECT property_id,
                COUNT(DISTINCT user_id) FILTER (
                  WHERE event_type = 'property_click' AND cohort = 'current'
                )::int AS clicks,
                COUNT(DISTINCT user_id) FILTER (
                  WHERE event_type = 'property_save' AND cohort = 'current'
                )::int AS saves,
                COUNT(DISTINCT user_id) FILTER (
                  WHERE event_type = 'property_save' AND cohort = 'previous'
                )::int AS previous_saves,
                COUNT(DISTINCT user_id) FILTER (
                  WHERE event_type = 'property_share' AND cohort = 'current'
                )::int AS shares
         FROM eligible_engagement
         GROUP BY property_id
       ), eligible_conversations AS MATERIALIZED (
         SELECT DISTINCT mc.property_id, mc.id, mc.created_at, v.cohort
         FROM message_conversations mc
         JOIN property_scope p ON p.id = mc.property_id
         JOIN view_cohorts v
           ON v.property_id = mc.property_id
          AND v.user_id = CASE
            WHEN mc.participant_one_id = $1 THEN mc.participant_two_id
            ELSE mc.participant_one_id
          END
          AND v.viewed_date::timestamptz <= mc.created_at
          AND v.cohort = CASE
            WHEN mc.created_at >= CURRENT_DATE - ($2::int - 1)
              THEN 'current'
            ELSE 'previous'
          END
         WHERE mc.context_type = 'property'
           AND mc.created_at >= CURRENT_DATE - ($2::int * 2 - 1)
           AND mc.created_at < CURRENT_DATE + 1
       ), conversations AS (
         SELECT property_id,
                COUNT(DISTINCT id) FILTER (WHERE cohort = 'current')::int AS enquiries,
                COUNT(DISTINCT id) FILTER (WHERE cohort = 'previous')::int AS previous_enquiries
         FROM eligible_conversations
         GROUP BY property_id
       ), eligible_bookings AS MATERIALIZED (
         SELECT DISTINCT b.property_id, b.id, b.created_at, v.cohort
         FROM bookings b
         JOIN property_scope p ON p.id = b.property_id
         JOIN view_cohorts v
           ON v.property_id = b.property_id
          AND v.user_id = b.tenant_id
          AND v.viewed_date::timestamptz <= b.created_at
          AND v.cohort = CASE
            WHEN b.created_at >= CURRENT_DATE - ($2::int - 1)
              THEN 'current'
            ELSE 'previous'
          END
         WHERE b.status NOT IN ('cancelled', 'rejected')
           AND b.created_at >= CURRENT_DATE - ($2::int * 2 - 1)
           AND b.created_at < CURRENT_DATE + 1
       ), bookings AS (
         SELECT property_id,
                COUNT(DISTINCT id) FILTER (WHERE cohort = 'current')::int AS bookings,
                COUNT(DISTINCT id) FILTER (WHERE cohort = 'previous')::int AS previous_bookings
         FROM eligible_bookings
         GROUP BY property_id
       ), performance AS (
         SELECT p.*, COALESCE(i.impressions, 0)::int AS impressions,
                COALESCE(v.views, 0)::int AS views,
                COALESCE(v.previous_views, 0)::int AS previous_views,
                COALESCE(v.unique_viewers, 0)::int AS unique_viewers,
                COALESCE(e.clicks, 0)::int AS clicks,
                COALESCE(e.saves, 0)::int AS saves,
                COALESCE(e.previous_saves, 0)::int AS previous_saves,
                COALESCE(e.shares, 0)::int AS shares,
                COALESCE(c.enquiries, 0)::int AS enquiries,
                COALESCE(c.previous_enquiries, 0)::int AS previous_enquiries,
                COALESCE(b.bookings, 0)::int AS bookings,
                COALESCE(b.previous_bookings, 0)::int AS previous_bookings
         FROM property_scope p
         LEFT JOIN views v ON v.property_id = p.id
         LEFT JOIN impressions i ON i.property_id = p.id
         LEFT JOIN engagement e ON e.property_id = p.id
         LEFT JOIN conversations c ON c.property_id = p.id
         LEFT JOIN bookings b ON b.property_id = p.id
       )
       SELECT * FROM performance
       ORDER BY views DESC, enquiries DESC, title ASC, id ASC
       OFFSET $4 LIMIT $5`, [req.auth?.id, days, search, offset, limit]);
        const total = Number(result.rows[0]?.total_count ?? 0);
        const propertyPerformance = result.rows.map((row) => ({
            id: String(row.id),
            title: String(row.title),
            imageUrl: row.image_url ? String(row.image_url) : null,
            city: row.city ? String(row.city) : null,
            location: row.location ? String(row.location) : null,
            price: Number(row.price ?? 0),
            status: String(row.status ?? 'draft'),
            availabilityStatus: String(row.availability_status ?? 'available'),
            impressions: Number(row.impressions ?? 0),
            views: Number(row.views ?? 0),
            clicks: Number(row.clicks ?? 0),
            viewsChangePercent: calculateGrowthPercent(Number(row.views ?? 0), Number(row.previous_views ?? 0)),
            uniqueViewers: Number(row.unique_viewers ?? 0),
            saves: Number(row.saves ?? 0),
            savesChangePercent: calculateGrowthPercent(Number(row.saves ?? 0), Number(row.previous_saves ?? 0)),
            shares: Number(row.shares ?? 0),
            enquiries: Number(row.enquiries ?? 0),
            enquiriesChangePercent: calculateGrowthPercent(Number(row.enquiries ?? 0), Number(row.previous_enquiries ?? 0)),
            bookings: Number(row.bookings ?? 0),
            bookingsChangePercent: calculateGrowthPercent(Number(row.bookings ?? 0), Number(row.previous_bookings ?? 0)),
            conversionRate: calculateRate(Number(row.enquiries ?? 0), Number(row.unique_viewers ?? 0)),
        }));
        res.json({
            propertyPerformance,
            total,
            hasMore: offset + propertyPerformance.length < total,
        });
    }
    catch (error) {
        next(error);
    }
});
router.get('/landlord-overview', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
    try {
        const filter = String(req.query.filter ?? 'This Week');
        if (!['This Week', 'Last 28 Days', 'Last 90 Days'].includes(filter)) {
            return res.status(400).json({ error: 'filter must be This Week, Last 28 Days, or Last 90 Days.' });
        }
        const window = getTimeWindow(filter);
        const landlordId = req.auth?.id;
        const daysCount = filter === 'Last 90 Days' ? 90 : filter === 'Last 28 Days' ? 28 : 7;
        // Parallelize all queries to prevent sequential processing bottlenecks 
        // and resolve "Connection reset by peer" errors caused by Render timeouts.
        const [statsResult, occupancyResult, chartResult, topProps, photoRows, deviationResult] = await Promise.all([
            query(`SELECT
           COALESCE((SELECT COUNT(*) FROM property_unique_views puv
                     JOIN properties pv ON pv.id = puv.property_id
                     WHERE pv.landlord_id = $1), 0) AS views,
           COALESCE((SELECT COUNT(DISTINCT puv.user_id) FROM property_unique_views puv
                     JOIN properties pv ON pv.id = puv.property_id
                     WHERE pv.landlord_id = $1), 0) AS unique_viewers,
           COALESCE(SUM(pa.saves), 0) AS saves,
           COALESCE(SUM(pa.shares), 0) AS shares,
           COALESCE(SUM(pa.impressions), 0) AS impressions,
           COALESCE(SUM(pa.clicks), 0) AS clicks,
           COALESCE((SELECT COUNT(*)::int
                       FROM bookings b
                      WHERE b.landlord_id = $1
                        AND b.status NOT IN ('cancelled', 'rejected')
                        AND b.created_at >= CURRENT_DATE - INTERVAL '${window}'), 0) AS bookings,
           COALESCE((SELECT COUNT(*)::int
                       FROM bookings b
                      WHERE b.landlord_id = $1
                        AND b.status NOT IN ('cancelled', 'rejected')
                        AND b.created_at >= CURRENT_DATE - INTERVAL '${daysCount * 2} days'
                        AND b.created_at < CURRENT_DATE - INTERVAL '${daysCount} days'), 0) AS previous_bookings
         FROM properties p
         LEFT JOIN property_analytics pa ON pa.property_id = p.id
         WHERE p.landlord_id = $1`, [landlordId]),
            query(`WITH current_window AS (
           SELECT CURRENT_DATE - ($2::int - 1) AS start_date,
                  CURRENT_DATE + 1 AS end_date
         ), previous_window AS (
           SELECT start_date - $2::int AS start_date,
                  start_date AS end_date
             FROM current_window
         ), property_count AS (
           SELECT COUNT(*)::int AS total
             FROM properties
            WHERE landlord_id = $1
              AND COALESCE(status, 'pending_review') = 'approved'
         ), booked_days AS (
           SELECT
             COALESCE(SUM(
               GREATEST(0,
                 LEAST(b.check_out_date, cw.end_date) -
                 GREATEST(b.check_in_date, cw.start_date)
               )
             ) FILTER (
               WHERE b.check_out_date > cw.start_date
                 AND b.check_in_date < cw.end_date
             ), 0)::int AS current_days,
             COALESCE(SUM(
               GREATEST(0,
                 LEAST(b.check_out_date, pw.end_date) -
                 GREATEST(b.check_in_date, pw.start_date)
               )
             ) FILTER (
               WHERE b.check_out_date > pw.start_date
                 AND b.check_in_date < pw.end_date
             ), 0)::int AS previous_days
           FROM bookings b
           CROSS JOIN current_window cw
           CROSS JOIN previous_window pw
           WHERE b.landlord_id = $1
             AND b.status IN ('confirmed', 'completed')
             AND (
               (b.check_out_date > cw.start_date AND b.check_in_date < cw.end_date)
               OR
               (b.check_out_date > pw.start_date AND b.check_in_date < pw.end_date)
             )
         )
         SELECT pc.total AS property_count,
                bd.current_days,
                bd.previous_days
           FROM property_count pc
           CROSS JOIN booked_days bd`, [landlordId, daysCount]),
            query(`SELECT puv.viewed_date AS day, COUNT(*)::int AS total
         FROM property_unique_views puv
         JOIN properties p ON p.id = puv.property_id
         WHERE p.landlord_id = $1
           AND puv.viewed_date >= CURRENT_DATE - INTERVAL '${window}'
         GROUP BY puv.viewed_date
         ORDER BY day ASC`, [landlordId]),
            query(`SELECT p.title AS name,
                p.city AS location,
                p.image_url AS image,
                (SELECT COUNT(*) FROM property_unique_views puv
                 WHERE puv.property_id = p.id)::text AS views
         FROM properties p
         JOIN property_analytics pa ON p.id = pa.property_id
         WHERE p.landlord_id = $1
         ORDER BY (SELECT COUNT(*) FROM property_unique_views puv WHERE puv.property_id = p.id) DESC, p.created_at DESC
         LIMIT 3`, [landlordId]),
            query(`SELECT p.title, p.image_url, COUNT(puv.property_id)::int AS engagement
         FROM properties p
         LEFT JOIN property_unique_views puv ON puv.property_id = p.id
         WHERE p.landlord_id = $1
         GROUP BY p.id, p.title, p.image_url
         ORDER BY engagement DESC
         LIMIT 3`, [landlordId]),
            query(`SELECT 
          (SELECT COUNT(*) FROM property_unique_views puv JOIN properties pv ON pv.id = puv.property_id WHERE pv.landlord_id = $1 AND puv.viewed_date >= CURRENT_DATE - INTERVAL '${daysCount} days') AS current_views,
          (SELECT COUNT(*) FROM property_unique_views puv JOIN properties pv ON pv.id = puv.property_id WHERE pv.landlord_id = $1 AND puv.viewed_date >= CURRENT_DATE - INTERVAL '${daysCount * 2} days' AND puv.viewed_date < CURRENT_DATE - INTERVAL '${daysCount} days') AS previous_views,
          0 AS unused_placeholder
        `, [landlordId])
        ]);
        const row = statsResult.rows[0] ?? {};
        const totalViews = toNumber(row.views);
        const totalClicks = toNumber(row.clicks);
        const totalImpressions = toNumber(row.impressions);
        const dateMap = new Map();
        chartResult.rows.forEach((r) => {
            const d = new Date(r.day);
            const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
            dateMap.set(key, toNumber(r.total));
        });
        const seriesData = [];
        for (let i = 0; i < daysCount; i++) {
            const d = new Date();
            d.setDate(d.getDate() - (daysCount - 1 - i));
            const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
            seriesData.push(dateMap.get(key) || 0);
        }
        const devRow = deviationResult.rows[0] ?? {};
        const currViews = toNumber(devRow.current_views);
        const prevViews = toNumber(devRow.previous_views);
        const bookings = toNumber(row.bookings);
        let growthValue = 0;
        if (prevViews > 0) {
            growthValue = ((currViews - prevViews) / prevViews) * 100;
        }
        else if (currViews > 0) {
            growthValue = 100;
        }
        const growthStr = (growthValue > 0 ? '+' : '') + growthValue.toFixed(1) + '%';
        const bookingsGrowthStr = formatGrowthPercent(calculateGrowthPercent(toNumber(row.bookings), toNumber(row.previous_bookings)));
        const occupancyMetrics = occupancyResult.rows[0] ?? {};
        const occupancyRate = calculateOccupancyRate(toNumber(occupancyMetrics.current_days), toNumber(occupancyMetrics.property_count), daysCount);
        const previousOccupancyRate = calculateOccupancyRate(toNumber(occupancyMetrics.previous_days), toNumber(occupancyMetrics.property_count), daysCount);
        const occupancyGrowthStr = formatGrowthPercent(calculateGrowthPercent(occupancyRate, previousOccupancyRate));
        res.json({
            overview: {
                totalViews: totalViews.toLocaleString(),
                growth: growthStr,
                chartData: seriesData,
            },
            metrics: {
                uniqueViewers: toNumber(row.unique_viewers).toLocaleString(),
                saves: toNumber(row.saves).toLocaleString(),
                shares: toNumber(row.shares).toLocaleString(),
                totalBookings: bookings.toLocaleString(),
                bookingsGrowth: bookingsGrowthStr,
                occupancyRate: `${occupancyRate.toFixed(1)}%`,
                occupancyGrowth: occupancyGrowthStr,
                avgCtr: totalImpressions > 0
                    ? `${((totalClicks / totalImpressions) * 100).toFixed(1)}%`
                    : '0%',
            },
            funnel: [
                {
                    label: 'Impressions',
                    value: totalImpressions.toLocaleString(),
                    percentage: 1.0,
                },
                {
                    label: 'Views',
                    value: totalViews.toLocaleString(),
                    percentage: totalImpressions > 0 ? totalViews / totalImpressions : 0,
                },
                {
                    label: 'Engagement',
                    value: (toNumber(row.saves) + totalClicks).toLocaleString(),
                    percentage: totalViews > 0 ? (toNumber(row.saves) + totalClicks) / totalViews : 0,
                },
                {
                    label: 'Bookings',
                    value: toNumber(row.bookings).toLocaleString(),
                    percentage: totalViews > 0 ? toNumber(row.bookings) / totalViews : 0,
                },
            ],
            topProperties: topProps.rows,
            photoPerformance: photoRows.rows.map((item, index) => ({
                label: item.title,
                image: item.image_url,
                engagement: item.engagement > 0 ? `${item.engagement.toLocaleString()} views` : 'No views yet',
                color: index === 0 ? 0xFF10B981 : index === 1 ? 0xFFF59E0B : 0xFFEF4444,
            })),
            insight: null,
        });
    }
    catch (error) {
        next(error);
    }
});
router.get('/management/:propertyId', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
    try {
        const { propertyId } = req.params;
        const propCheck = await query('SELECT landlord_id FROM properties WHERE id = $1', [propertyId]);
        if (propCheck.rowCount === 0)
            return res.status(404).json({ error: 'Property not found.' });
        if (propCheck.rows[0].landlord_id !== req.auth?.id) {
            return res.status(403).json({ error: 'You are not authorized to view management data for this property.' });
        }
        const stats = await query(`SELECT pa.*
       FROM property_analytics pa
       WHERE pa.property_id = $1`, [propertyId]);
        const activity = await query(`SELECT event_type AS type, created_at
       FROM engagement_events
       WHERE property_id = $1
       ORDER BY created_at DESC
       LIMIT 5`, [propertyId]);
        const leads = await query(`SELECT u.name, u.avatar, COUNT(*)::int AS interaction_count
       FROM engagement_events ee
       JOIN users u ON u.id = ee.user_id
       WHERE ee.property_id = $1
       GROUP BY u.id, u.name, u.avatar
       HAVING COUNT(*) > 2 OR EXISTS (
         SELECT 1 FROM engagement_events
         WHERE event_type = 'property_save' AND user_id = u.id
       )
       ORDER BY interaction_count DESC
       LIMIT 5`, [propertyId]);
        res.json({
            stats: stats.rows[0] ?? {},
            health: stats.rows[0]?.engagement_score && stats.rows[0].engagement_score > 0 ? 'HEALTHY' : 'NEW',
            activity: activity.rows,
            leads: leads.rows,
            isBoosted: false,
        });
    }
    catch (error) {
        next(error);
    }
});
router.get('/trending-properties', async (req, res, next) => {
    try {
        const period = typeof req.query.period === 'string' ? req.query.period.toLowerCase() : '7d';
        // const windowDays = period === '28d' ? 28 : period === 'all' ? null : 7;
        const limit = typeof req.query.limit === 'string'
            ? Math.max(1, Math.min(50, Number(req.query.limit) || 12))
            : 12;
        // NOTE: dateFilter is kept for future CTE-based scoring; current query uses a fixed 7d window.
        // const dateFilter = windowDays ? `WHERE pa.last_event_at >= NOW() - INTERVAL '${windowDays} days'` : '';
        const result = await query(`SELECT
         p.id,
         p.title,
         p.price,
         p.city AS location,
         COALESCE(pa.engagement_score, 0)::float AS engagement_score,
         COALESCE(pa.impressions, 0)::int AS impressions,
         COALESCE(pa.views, 0)::int AS views,
         COALESCE(pa.clicks, 0)::int AS clicks,
         COALESCE(pa.saves, 0)::int AS saves
       FROM properties p
       JOIN property_analytics pa ON pa.property_id = p.id
       WHERE pa.last_event_at >= NOW() - INTERVAL '7 days'
         AND pa.views > 0
       ORDER BY
         pa.engagement_score DESC,
         (pa.impressions::float / NULLIF(pa.views, 0)) ASC,
         p.created_at DESC
       LIMIT $1`, 
        // NOTE: This limit is for the pre-selection set; the final result is also limited later.
        [limit]);
        // Keep existing API shape; if you want to use the full CTE-based scoring query, re-add it here.
        res.json({
            period,
            count: result.rowCount,
            data: result.rows.map((row) => ({
                id: row.id,
                title: row.title,
                price: Number(row.price ?? 0),
                location: row.location,
                engagementScore: Number(row.engagement_score ?? row.engagementScore ?? 0),
                trendingScore: Number(0),
                impressions: Number(row.impressions ?? 0),
                views: Number(row.views ?? 0),
                clicks: Number(row.clicks ?? 0),
                saves: Number(row.saves ?? 0),
                ctr: Number(0),
                impressionToViewRate: Number(0),
                imageUrl: row.image_url ?? row.imageUrl ?? null,
            })),
        });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=analytics.js.map