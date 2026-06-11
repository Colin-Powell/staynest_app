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
    const n = typeof value === 'number' ? value : Number(value ?? 0);
    return Number.isFinite(n) ? n : 0;
}
router.post('/track', requireAuth, async (req, res, next) => {
    try {
        const { eventType, userId, propertyId, sessionId, metadata = {}, } = req.body;
        if (!eventType || !propertyId) {
            return res.status(400).json({ error: 'eventType and propertyId are required.' });
        }
        const propertyExists = await query('SELECT 1 FROM properties WHERE id = $1 LIMIT 1', [propertyId]);
        if (propertyExists.rowCount === 0) {
            return res.status(404).json({ error: 'Property not found.' });
        }
        await query(`INSERT INTO engagement_events (user_id, property_id, event_type, session_id, metadata, created_at)
       VALUES ($1, $2, $3, $4, $5, NOW())`, [userId ?? null, propertyId, eventType, sessionId ?? null, metadata]);
        const uniqueView = userId && propertyId && (eventType === 'property_view' || eventType === 'property_detail_view')
            ? (await query(`INSERT INTO property_unique_views (property_id, user_id, viewed_date)
             VALUES ($1, $2, CURRENT_DATE)
             ON CONFLICT (property_id, user_id, viewed_date) DO NOTHING`, [propertyId, userId])).rowCount ?? 0
            : 0;
        const weight = EVENT_WEIGHTS[eventType] ?? 0;
        const score = weight * (uniqueView > 0 ? 1.5 : 1);
        const column = METRIC_COLUMNS[eventType];
        const uniqueInc = uniqueView > 0 ? 1 : 0;
        await query(`INSERT INTO property_analytics (property_id, views, unique_views, impressions, clicks, saves, shares, chats, booking_requested, bookings_confirmed, bookings_completed, engagement_score, last_event_at, updated_at)
       VALUES ($1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NOW(), NOW())
       ON CONFLICT (property_id) DO NOTHING`, [propertyId]);
        await query(`UPDATE property_analytics
       SET ${column ? `${column} = property_analytics.${column} + 1,` : ''}
           unique_views = property_analytics.unique_views + $2,
           engagement_score = COALESCE(property_analytics.engagement_score, 0) + $3,
           last_event_at = NOW(),
           updated_at = NOW()
       WHERE property_id = $1`, [propertyId, uniqueInc, score]);
        res.status(201).json({ ok: true, eventType, uniqueView });
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
        const statsResult = await query(`SELECT
         COALESCE(SUM(pa.views), 0) AS views,
         COALESCE(SUM(pa.unique_views), 0) AS unique_viewers,
         COALESCE(SUM(pa.saves), 0) AS saves,
         COALESCE(SUM(pa.shares), 0) AS shares,
         COALESCE(SUM(pa.impressions), 0) AS impressions,
         COALESCE(SUM(pa.clicks), 0) AS clicks,
         COALESCE(SUM(pa.bookings_completed), 0) AS bookings
       FROM property_analytics pa
       JOIN properties p ON p.id = pa.property_id
       WHERE p.landlord_id = $1`, [landlordId]);
        const row = statsResult.rows[0] ?? {};
        const chartResult = await query(`SELECT DATE(created_at) AS day, COUNT(*)::int AS total
       FROM engagement_events ee
       JOIN properties p ON p.id = ee.property_id
       WHERE p.landlord_id = $1
         AND ee.created_at >= NOW() - INTERVAL '${window}'
         AND ee.event_type IN ('property_view', 'property_detail_view')
       GROUP BY DATE(created_at)
       ORDER BY day ASC`, [landlordId]);
        const topProps = await query(`SELECT p.title AS name,
              p.city AS location,
              p.image_url AS image,
              COALESCE(pa.views, 0)::text AS views
       FROM properties p
       JOIN property_analytics pa ON p.id = pa.property_id
       WHERE p.landlord_id = $1
       ORDER BY pa.views DESC, p.created_at DESC
       LIMIT 3`, [landlordId]);
        const photoRows = await query(`SELECT title, image_url
       FROM properties
       WHERE landlord_id = $1
       ORDER BY created_at DESC
       LIMIT 3`, [landlordId]);
        const totalViews = toNumber(row.views);
        const totalClicks = toNumber(row.clicks);
        const totalImpressions = toNumber(row.impressions);
        res.json({
            overview: {
                totalViews: totalViews.toLocaleString(),
                growth: '0%',
                chartData: chartResult.rows.map((item) => toNumber(item.total)),
            },
            metrics: {
                uniqueViewers: toNumber(row.unique_viewers).toLocaleString(),
                saves: toNumber(row.saves).toLocaleString(),
                shares: toNumber(row.shares).toLocaleString(),
                avgCtr: totalImpressions > 0 ? `${((totalClicks / totalImpressions) * 100).toFixed(1)}%` : '0%',
            },
            funnel: [
                { label: 'Impressions', value: totalImpressions.toLocaleString(), percentage: 1.0 },
                { label: 'Views', value: totalViews.toLocaleString(), percentage: totalImpressions > 0 ? totalViews / totalImpressions : 0 },
                { label: 'Engagement', value: (toNumber(row.saves) + totalClicks).toLocaleString(), percentage: totalViews > 0 ? (toNumber(row.saves) + totalClicks) / totalViews : 0 },
                { label: 'Bookings', value: toNumber(row.bookings).toLocaleString(), percentage: totalViews > 0 ? toNumber(row.bookings) / totalViews : 0 },
            ],
            topProperties: topProps.rows,
            photoPerformance: photoRows.rows.map((item, index) => ({
                label: item.title,
                image: item.image_url,
                engagement: index === 0 ? 'High engagement' : index === 1 ? 'Growing interest' : 'Emerging interest',
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
       HAVING COUNT(*) > 2 OR EXISTS (SELECT 1 FROM engagement_events WHERE event_type = 'property_save' AND user_id = u.id)
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
export default router;
//# sourceMappingURL=analytics.js.map