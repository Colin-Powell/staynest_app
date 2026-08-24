import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
const router = Router();
const EVENT_WEIGHTS = {
    property_impression: 0.1,
    featured_property_impression: 0.1,
    map_property_impression: 0.1,
    saved_property_impression: 0.1,
    owner_property_impression: 0.1,
    recommended_property_impression: 0.1,
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
    property_impression: 'impressions',
    featured_property_impression: 'impressions',
    map_property_impression: 'impressions',
    saved_property_impression: 'impressions',
    owner_property_impression: 'impressions',
    recommended_property_impression: 'impressions',
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
router.post('/track', requireAuth, async (req, res, next) => {
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
    try {
        const { eventType, propertyId, sessionId, metadata = {}, } = req.body;
        const userId = req.auth?.id;
        if (!eventType || !propertyId) {
            return res.status(400).json({ error: 'eventType and propertyId are required.' });
        }
        const propertyExists = await query('SELECT landlord_id FROM properties WHERE id = $1 LIMIT 1', [propertyId]);
        if (propertyExists.rowCount === 0) {
            return res.status(404).json({ error: 'Property not found.' });
        }
        if (userId && userId === propertyExists.rows[0].landlord_id) {
            // Don't track interactions if the landlord is viewing their own property
            return res.status(200).json({ ok: true, ignored: true, reason: 'landlord_own_property' });
        }
        await query('BEGIN');
        try {
            const isViewEvent = eventType === 'property_view' || eventType === 'property_detail_view';
            const isSaveEvent = eventType === 'property_save';
            let isFirstAction = true;
            if (isViewEvent || isSaveEvent) {
                if (userId) {
                    const priorCheck = await query(`SELECT 1 FROM engagement_events 
             WHERE user_id = $1 AND property_id = $2 
               AND event_type ${isViewEvent ? "IN ('property_view', 'property_detail_view')" : "= 'property_save'"}
             LIMIT 1`, [userId, propertyId]);
                    isFirstAction = (priorCheck.rowCount ?? 0) === 0;
                }
                else if (sessionId) {
                    const priorCheck = await query(`SELECT 1 FROM engagement_events 
             WHERE session_id = $1 AND property_id = $2 
               AND event_type ${isViewEvent ? "IN ('property_view', 'property_detail_view')" : "= 'property_save'"}
             LIMIT 1`, [sessionId, propertyId]);
                    isFirstAction = (priorCheck.rowCount ?? 0) === 0;
                }
            }
            await query(`INSERT INTO engagement_events (user_id, property_id, event_type, session_id, metadata, created_at)
         VALUES ($1, $2, $3, $4, $5, NOW())`, [userId, propertyId, eventType, sessionId ?? null, metadata]);
            if (userId && propertyId && isViewEvent) {
                await query(`INSERT INTO property_unique_views (property_id, user_id, viewed_date)
           VALUES ($1, $2, CURRENT_DATE)
           ON CONFLICT (property_id, user_id, viewed_date) DO NOTHING`, [propertyId, userId]);
            }
            const weight = EVENT_WEIGHTS[eventType] ?? 0;
            const score = weight * (isFirstAction ? 1.5 : (isViewEvent || isSaveEvent ? 0 : 1));
            const column = METRIC_COLUMNS[eventType];
            const uniqueInc = (isViewEvent && isFirstAction) ? 1 : 0;
            const metricInc = (isViewEvent || isSaveEvent) ? (isFirstAction ? 1 : 0) : 1;
            await query(`INSERT INTO property_analytics (property_id, views, unique_views, impressions, clicks, saves, shares, chats, booking_requested, bookings_confirmed, bookings_completed, engagement_score, last_event_at, updated_at)
         VALUES ($1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NOW(), NOW())
         ON CONFLICT (property_id) DO NOTHING`, [propertyId]);
            await query(`UPDATE property_analytics
         SET ${column ? `${column} = property_analytics.${column} + $4,` : ''}
           unique_views = property_analytics.unique_views + $2,
           engagement_score = COALESCE(property_analytics.engagement_score, 0) + $3,
           last_event_at = NOW(),
           updated_at = NOW()
       WHERE property_id = $1`, [propertyId, uniqueInc, score, metricInc]);
            await query('COMMIT');
            res.status(201).json({ ok: true, eventType, uniqueInc });
        }
        catch (error) {
            await query('ROLLBACK');
            throw error;
        }
    }
    catch (error) {
        next(error);
    }
});
router.get('/stats/:propertyId', requireAuth, async (req, res, next) => {
    try {
        const { propertyId } = req.params;
        const result = await query(`SELECT pa.*,
              p.title,
              p.image_url,
              p.landlord_id
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
        const views = toNumber(row.views);
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
                uniqueViews: toNumber(row.unique_views),
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
router.get('/landlord-overview', requireAuth, async (req, res, next) => {
    try {
        const filter = String(req.query.filter ?? 'This Week');
        const window = getTimeWindow(filter);
        const landlordId = req.auth?.id;
        const daysCount = filter === 'Last 28 Days' ? 28 : 7;
        // Parallelize all queries to prevent sequential processing bottlenecks 
        // and resolve "Connection reset by peer" errors caused by Render timeouts.
        const [statsResult, occupancyResult, chartResult, topProps, photoRows] = await Promise.all([
            query(`SELECT
           COALESCE(SUM(pa.views), 0) AS views,
           COALESCE(SUM(pa.unique_views), 0) AS unique_viewers,
           COALESCE(SUM(pa.saves), 0) AS saves,
           COALESCE(SUM(pa.shares), 0) AS shares,
           COALESCE(SUM(pa.impressions), 0) AS impressions,
           COALESCE(SUM(pa.clicks), 0) AS clicks,
           COALESCE(SUM(pa.bookings_completed), 0) AS bookings
         FROM property_analytics pa
         JOIN properties p ON p.id = pa.property_id
         WHERE p.landlord_id = $1`, [landlordId]),
            query(`WITH prop_count AS (
           SELECT COUNT(*)::int as total FROM properties WHERE landlord_id = $1
         ),
         booked_days AS (
           SELECT COALESCE(SUM(check_out_date - check_in_date), 0)::int as days
           FROM bookings
           WHERE landlord_id = $1 AND status IN ('confirmed', 'completed')
             AND check_in_date >= NOW() - INTERVAL '${window}'
         )
         SELECT 
           CASE WHEN pc.total > 0 THEN (bd.days::float / (pc.total * ${daysCount})) * 100 ELSE 0 END as rate
         FROM prop_count pc, booked_days bd`, [landlordId]),
            query(`SELECT DATE(ee.created_at) AS day, COUNT(*)::int AS total
         FROM engagement_events ee
         JOIN properties p ON p.id = ee.property_id
         WHERE p.landlord_id = $1
           AND ee.created_at >= NOW() - INTERVAL '${window}'
           AND ee.event_type IN ('property_view', 'property_detail_view')
         GROUP BY DATE(ee.created_at)
         ORDER BY day ASC`, [landlordId]),
            query(`SELECT p.title AS name,
                p.city AS location,
                p.image_url AS image,
                COALESCE(pa.views, 0)::text AS views
         FROM properties p
         JOIN property_analytics pa ON p.id = pa.property_id
         WHERE p.landlord_id = $1
         ORDER BY pa.views DESC, p.created_at DESC
         LIMIT 3`, [landlordId]),
            query(`SELECT p.title, p.image_url, COUNT(ee.id)::int AS engagement
         FROM properties p
         LEFT JOIN engagement_events ee ON ee.property_id = p.id AND ee.event_type = 'property_view'
         WHERE p.landlord_id = $1
         GROUP BY p.id, p.title, p.image_url
         ORDER BY engagement DESC
         LIMIT 3`, [landlordId])
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
        res.json({
            overview: {
                totalViews: totalViews.toLocaleString(),
                growth: '0%',
                chartData: seriesData,
            },
            metrics: {
                uniqueViewers: toNumber(row.unique_viewers).toLocaleString(),
                saves: toNumber(row.saves).toLocaleString(),
                shares: toNumber(row.shares).toLocaleString(),
                totalBookings: toNumber(row.bookings).toLocaleString(),
                occupancyRate: occupancyResult.rows[0]?.rate ? Number(occupancyResult.rows[0].rate).toFixed(1) + '%' : '0%',
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
router.get('/management/:propertyId', requireAuth, async (req, res, next) => {
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