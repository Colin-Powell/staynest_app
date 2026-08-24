import { Router, Request, Response, NextFunction } from 'express';
import { query } from '../db.js';
import { requireAuth, authorize } from '../middleware/auth.js';
const router = Router();

router.get('/overview', requireAuth, authorize('admin'), async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const [usersRes, propertiesRes, verificationsRes, bookingsRes, revenueRes, monthlyRevenueRes, locationsRes, rejectionsRes, eventsRes, backlogRes] = await Promise.all([
      query("SELECT COUNT(*)::int AS count FROM users"),
      query("SELECT COUNT(*)::int AS count FROM properties"),
      query("SELECT COUNT(*)::int AS count FROM verifications WHERE status IN ('submitted', 'under_review', 'manual_review')"),
      query("SELECT COUNT(*)::int AS count FROM bookings"),
      query("SELECT COALESCE(SUM(total_price), 0)::numeric AS total FROM bookings WHERE status IN ('confirmed', 'completed')"),
      query("SELECT COALESCE(SUM(total_price), 0)::numeric AS total FROM bookings WHERE status IN ('confirmed', 'completed') AND created_at >= CURRENT_DATE - INTERVAL '30 days'"),
      query(`
        SELECT COALESCE(NULLIF(p.city, ''), 'Unknown') AS label, COUNT(*)::int AS value
        FROM engagement_events e
        JOIN properties p ON p.id = e.property_id
        WHERE e.event_type IN ('property_view', 'property_detail_view')
          AND e.created_at >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY COALESCE(NULLIF(p.city, ''), 'Unknown')
        ORDER BY value DESC LIMIT 5
      `),
      query(`
        SELECT COALESCE(NULLIF(split_part(admin_notes, ':', 1), ''), 'Other') AS label, COUNT(*)::int AS value
        FROM verifications
        WHERE status = 'rejected' AND updated_at >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY COALESCE(NULLIF(split_part(admin_notes, ':', 1), ''), 'Other')
        ORDER BY value DESC LIMIT 5
      `),
      query(`
        SELECT event_type AS label, COUNT(*)::int AS value
        FROM engagement_events
        WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
        GROUP BY event_type ORDER BY value DESC LIMIT 5
      `),
      query(`
        WITH dates AS (
          SELECT generate_series(CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE, '1 day'::interval)::date AS date
        )
        SELECT to_char(d.date, 'Mon DD') AS label,
               COUNT(v.id) FILTER (WHERE v.status IN ('submitted', 'under_review', 'manual_review'))::int AS value
        FROM dates d
        LEFT JOIN verifications v ON v.created_at < d.date + INTERVAL '1 day'
        GROUP BY d.date ORDER BY d.date ASC
      `),
    ]);

    // 1. General Growth Chart (Users & Bookings)
    const chartRes = await query(`
      WITH dates AS (
        SELECT generate_series(CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE, '1 day'::interval)::date AS date
      )
      SELECT to_char(d.date, 'Mon DD') as label,
             COUNT(DISTINCT u.id)::int as new_users,
             COUNT(DISTINCT b.id)::int as new_bookings
      FROM dates d
      LEFT JOIN users u ON DATE(u.created_at) = d.date
      LEFT JOIN bookings b ON DATE(b.created_at) = d.date
      GROUP BY d.date ORDER BY d.date ASC;
    `);

    // 2. Verification Trends Chart
    const verifRes = await query(`
      WITH dates AS (
        SELECT generate_series(CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE, '1 day'::interval)::date AS date
      )
      SELECT to_char(d.date, 'Mon DD') as label,
             COALESCE((COUNT(CASE WHEN v.status = 'approved' THEN 1 END)::numeric / NULLIF(COUNT(v.id), 0)) * 100, 0)::int as success_rate
      FROM dates d
      LEFT JOIN verifications v ON DATE(v.created_at) = d.date
      GROUP BY d.date ORDER BY d.date ASC;
    `);

    // 3. User Retention Chart (Day 7, 14, 21, 28, 35)
    // Percentage of users returning X days after their signup
    const retentionRes = await query(`
      WITH user_cohorts AS (
        SELECT id, DATE(created_at) as signup_date FROM users
      ),
      returning_users AS (
        SELECT u.id, u.signup_date, DATE(e.created_at) as active_date
        FROM user_cohorts u
        JOIN engagement_events e ON u.id = e.user_id
      ),
      intervals AS (
        SELECT unnest(ARRAY[7, 14, 21, 28, 35]) as day_interval
      )
      SELECT i.day_interval as label_day,
             COALESCE((COUNT(DISTINCT r.id) FILTER (WHERE r.active_date >= r.signup_date + i.day_interval - 3 AND r.active_date <= r.signup_date + i.day_interval + 3)::numeric / NULLIF(COUNT(DISTINCT u.id), 0)) * 100, 0)::int as retention_rate
      FROM intervals i
      CROSS JOIN user_cohorts u
      LEFT JOIN returning_users r ON u.id = r.id
      GROUP BY i.day_interval
      ORDER BY i.day_interval ASC;
    `);

    // 4. Landlord Cohorts (Simulated or Real Activity over months)
    const cohortRes = await query(`
      SELECT to_char(DATE_TRUNC('month', created_at), 'Mon YYYY') as cohort,
             COUNT(id)::int as active_landlords
      FROM users WHERE role = 'landlord'
      GROUP BY DATE_TRUNC('month', created_at)
      ORDER BY DATE_TRUNC('month', created_at) DESC
      LIMIT 5;
    `);

    res.json({
      success: true,
      data: {
        totalUsers: usersRes.rows[0].count,
        totalProperties: propertiesRes.rows[0].count,
        pendingVerifications: verificationsRes.rows[0].count,
        totalBookings: bookingsRes.rows[0].count,
        totalRevenue: parseFloat(revenueRes.rows[0].total),
        monthlyRevenue: parseFloat(monthlyRevenueRes.rows[0].total),
        chartData: chartRes.rows,
        verificationData: verifRes.rows,
        retentionData: retentionRes.rows,
        cohortData: cohortRes.rows,
        topLocations: locationsRes.rows,
        kycRejections: rejectionsRes.rows,
        keyEvents: eventsRes.rows,
        backlogData: backlogRes.rows,
      }
    });
  } catch (err) {
    next(err);
  }
});

export default router;
