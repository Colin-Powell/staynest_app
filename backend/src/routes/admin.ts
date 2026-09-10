import { Router, Request, Response, NextFunction } from 'express';
import { query } from '../db.js';
import { requireAuth, authorize } from '../middleware/auth.js';
import { cache } from '../services/cache.js';
import { sendPushToUser } from '../services/firebase.js';
import { finalizeVerificationDecision } from './verifications.js';
import { pool } from '../db.js';
import { initiateB2CPayout } from '../services/mpesa.js';
import { recordAdminAudit } from '../services/audit_service.js';

const router = Router();

router.get('/withdrawals', requireAuth, authorize('admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const status = String(req.query.status ?? 'pending');
    const allowed = ['pending', 'approved', 'processing', 'paid', 'failed', 'rejected'];
    if (!allowed.includes(status)) return res.status(400).json({ error: 'Invalid withdrawal status.' });
    const result = await query(
      `SELECT w.*, u.name AS user_name, u.email AS user_email, u.phone AS user_phone
       FROM wallet_withdrawals w JOIN users u ON u.id = w.user_id
       WHERE w.status = $1 ORDER BY w.created_at ASC LIMIT 100`, [status],
    );
    res.json({ data: result.rows });
  } catch (error) { next(error); }
});

router.patch('/withdrawals/:id/approve', requireAuth, authorize('admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      `UPDATE wallet_withdrawals SET status = 'approved', approved_by = $1, approved_at = NOW()
       WHERE id = $2 AND status = 'pending' RETURNING id, status`, [req.auth!.id, req.params.id],
    );
    if (result.rows.length === 0) return res.status(409).json({ error: 'Withdrawal is no longer pending.' });
    await recordAdminAudit(req, 'withdrawal_approved', 'wallet_withdrawal', req.params.id);
    res.json({ data: result.rows[0] });
  } catch (error) { next(error); }
});

router.post('/withdrawals/:id/release', requireAuth, authorize('admin'), async (req: Request, res: Response, next: NextFunction) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
      `UPDATE wallet_withdrawals SET status = 'processing', released_by = $1
       WHERE id = $2 AND status = 'approved'
       RETURNING id, amount, destination_account`, [req.auth!.id, req.params.id],
    );
    if (result.rows.length === 0) { await client.query('ROLLBACK'); return res.status(409).json({ error: 'Withdrawal must be approved before release.' }); }
    await client.query('COMMIT');
    try {
      const payout = await initiateB2CPayout({
        phone: result.rows[0].destination_account,
        amount: Number(result.rows[0].amount),
        reference: result.rows[0].id,
        remarks: 'StayNest wallet withdrawal',
      });
      await query(
        `UPDATE wallet_withdrawals SET provider_reference = $1 WHERE id = $2`,
        [payout.conversationId, result.rows[0].id],
      );
      await recordAdminAudit(req, 'withdrawal_released', 'wallet_withdrawal', req.params.id, { providerReference: payout.conversationId });
      res.json({ data: { id: result.rows[0].id, status: 'processing', providerReference: payout.conversationId } });
    } catch (error: any) {
      await query(`UPDATE wallet_withdrawals SET status = 'approved', failure_reason = $1 WHERE id = $2`, [error.message, result.rows[0].id]);
      next(error);
    }
  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally { client.release(); }
});

router.get('/audit-logs', requireAuth, authorize('admin'), async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      `SELECT a.*, u.name AS admin_name FROM admin_audit_logs a
       LEFT JOIN users u ON u.id = a.admin_id ORDER BY a.created_at DESC LIMIT 200`, [],
    );
    res.json({ data: result.rows });
  } catch (error) { next(error); }
});

const defaultPlatformSettings: Record<string, Record<string, unknown>> = {
  general: {
    requireManualKyc: true,
    autoApproveListings: false,
    globalFee: 10,
    defaultCurrency: 'Ksh.',
  },
  security: {
    enforce2FA: true,
    maintenanceMode: false,
  },
};

const settingKeys = new Set(Object.keys(defaultPlatformSettings));

const ensurePlatformSettings = async () => {
  await query(`
    CREATE TABLE IF NOT EXISTS platform_settings (
      key VARCHAR(255) PRIMARY KEY,
      value JSONB NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  for (const [key, value] of Object.entries(defaultPlatformSettings)) {
    await query(
      `INSERT INTO platform_settings (key, value)
       VALUES ($1, $2::jsonb)
       ON CONFLICT (key) DO NOTHING`,
      [key, JSON.stringify(value)],
    );
  }
};

router.get('/settings', requireAuth, authorize('admin'), async (_req: Request, res: Response, next: NextFunction) => {
  try {
    await ensurePlatformSettings();
    const result = await query('SELECT key, value FROM platform_settings ORDER BY key');
    const settings = Object.fromEntries(result.rows.map((row) => [row.key, row.value]));
    return res.json({ data: settings });
  } catch (err) {
    next(err);
  }
});

router.put('/settings/:key', requireAuth, authorize('admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const key = req.params.key;
    if (!settingKeys.has(key) || !req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
      return res.status(400).json({ error: 'Invalid platform settings payload.' });
    }

    const allowedFields = Object.keys(defaultPlatformSettings[key]);
    const unknownFields = Object.keys(req.body).filter((field) => !allowedFields.includes(field));
    if (unknownFields.length > 0) {
      return res.status(400).json({ error: `Unsupported setting fields: ${unknownFields.join(', ')}` });
    }

    await ensurePlatformSettings();
    const existing = await query('SELECT value FROM platform_settings WHERE key = $1', [key]);
    const current = existing.rows[0]?.value ?? defaultPlatformSettings[key];
    const value = { ...current, ...req.body };

    if (key === 'general') {
      if (typeof value.requireManualKyc !== 'boolean' || typeof value.autoApproveListings !== 'boolean' ||
          typeof value.globalFee !== 'number' || value.globalFee < 0 || value.globalFee > 100 ||
          typeof value.defaultCurrency !== 'string') {
        return res.status(400).json({ error: 'Invalid general settings values.' });
      }
    }
    if (key === 'security' &&
        (typeof value.enforce2FA !== 'boolean' || typeof value.maintenanceMode !== 'boolean')) {
      return res.status(400).json({ error: 'Invalid security settings values.' });
    }

    const result = await query(
      `INSERT INTO platform_settings (key, value, updated_at)
       VALUES ($1, $2::jsonb, NOW())
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
       RETURNING key, value, updated_at`,
      [key, JSON.stringify(value)],
    );
    await recordAdminAudit(req, 'platform_setting_updated', 'platform_setting', null, { key, fields: Object.keys(req.body) });
    return res.json({ data: result.rows[0] });
  } catch (err) {
    next(err);
  }
});

// GET /admin/users - List all users with metadata
router.get('/users', requireAuth, authorize('admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const limit = Math.min(Math.max(Number(req.query.limit) || 10, 1), 100);
    const offset = Math.max(Number(req.query.offset) || 0, 0);
    const search = String(req.query.search || '');
    const role = String(req.query.role || '');
    const conditions: string[] = [];
    const params: unknown[] = [];
    let parameter = 1;

    if (role) { conditions.push(`u.role = $${parameter++}`); params.push(role); }
    if (search) {
      conditions.push(`(u.name ILIKE $${parameter} OR u.email ILIKE $${parameter} OR u.phone ILIKE $${parameter})`);
      params.push(`%${search}%`); parameter++;
    }
    params.push(limit, offset);

    const usersRes = await query(`
      SELECT u.id, u.name, u.email, u.phone, u.role, u.verified, u.avatar, 'active' as status, u.created_at, u.created_at as updated_at,
        (SELECT COUNT(*)::int FROM properties p WHERE p.landlord_id = u.id AND p.status = 'approved') AS active_property_count,
        (SELECT COUNT(*)::int FROM properties p WHERE p.landlord_id = u.id) AS total_property_count,
        (SELECT COUNT(*)::int FROM bookings b WHERE b.landlord_id = u.id) AS booking_count_as_landlord,
        (SELECT COUNT(*)::int FROM bookings b WHERE b.tenant_id = u.id) AS booking_count_as_tenant,
        (SELECT COALESCE(SUM(b.total_price), 0)::numeric FROM bookings b WHERE b.landlord_id = u.id AND b.status IN ('confirmed', 'completed')) AS total_revenue,
        (SELECT MAX(e.created_at)::timestamptz FROM engagement_events e WHERE e.user_id = u.id) AS last_active_at
      FROM users u
      ${conditions.length ? `WHERE ${conditions.join(' AND ')}` : ''}
      ORDER BY u.created_at DESC LIMIT $${parameter} OFFSET $${parameter + 1}
    `, params);

    res.json({
      success: true,
      data: usersRes.rows.map(row => ({
        id: row.id,
        name: row.name,
        email: row.email,
        phone: row.phone,
          avatar: row.avatar,
        role: row.role,
        verified: row.verified,
        
        created_at: row.created_at,
        
        property_count: row.total_property_count,
        active_property_count: row.active_property_count,
        booking_count_as_landlord: row.booking_count_as_landlord,
        booking_count_as_tenant: row.booking_count_as_tenant,
        total_revenue: parseFloat(row.total_revenue) || 0,
        last_active_at: row.last_active_at,
      }))
    });
  } catch (err) {
    next(err);
  }
});

// GET /admin/properties - List properties for moderation with metadata
router.get('/properties', requireAuth, authorize('admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const limit = parseInt(req.query.limit as string) || 10;
    const offset = parseInt(req.query.offset as string) || 0;
    const status = (req.query.status as string) || '';
    const search = (req.query.search as string) || '';

    // Build conditions
    const conditions = [];
    const params: any[] = [];
    let paramCount = 1;

    if (status) {
      conditions.push(`p.status = $${paramCount}`);
      params.push(status);
      paramCount++;
    }

    if (search) {
      conditions.push(`(p.title ILIKE $${paramCount} OR p.city ILIKE $${paramCount} OR p.address ILIKE $${paramCount})`);
      params.push(`%${search}%`);
      paramCount++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    params.push(limit);
    params.push(offset);

    const propertiesRes = await query(`
      SELECT
        p.id,
        p.title,
        p.description,
        p.category,
        p.city,
        p.address,
        p.lat,
        p.lng,
        p.price,
        p.bedrooms,
        p.bathrooms,
        p.area,
        p.amenities,
        p.images,
        p.image_url,
        p.status,
        p.created_at,
        p.created_at as updated_at,
        u.id as landlord_id,
        u.name as landlord_name,
        u.email as landlord_email,
        u.verified as landlord_verified,
        COALESCE(jsonb_array_length(p.images), 0)::int as image_count,
        COUNT(DISTINCT b.id)::int as booking_count,
        COALESCE(SUM(CASE WHEN b.status IN ('confirmed', 'completed') THEN b.total_price ELSE 0 END), 0)::numeric as total_revenue
      FROM properties p
      LEFT JOIN users u ON p.landlord_id = u.id
      LEFT JOIN bookings b ON p.id = b.property_id
      ${whereClause}
      GROUP BY p.id, u.id, u.name, u.email, u.verified
      ORDER BY p.created_at DESC
      LIMIT $${paramCount} OFFSET $${paramCount + 1}
    `, [...params]);

    res.json({
      success: true,
      data: propertiesRes.rows.map(row => ({
        id: row.id,
        title: row.title,
        description: row.description,
        category: row.category,
        city: row.city,
        address: row.address,
        lat: row.lat,
        lng: row.lng,
        price: parseFloat(row.price) || 0,
        bedrooms: row.bedrooms,
        bathrooms: row.bathrooms,
        area: row.area,
        amenities: row.amenities,
        image_url: row.image_url,
        images: row.images || [],
        image_count: row.image_count,
        booking_count: row.booking_count,
        total_revenue: parseFloat(row.total_revenue) || 0,
        status: row.status,
        created_at: row.created_at,
        
        landlord_id: row.landlord_id,
        landlord_name: row.landlord_name,
        landlord_email: row.landlord_email,
        landlord_verified: row.landlord_verified,
      }))
    });
  } catch (err) {
    next(err);
  }
});

// GET /admin/kyc - List KYC verifications for review with metadata
router.get('/kyc', requireAuth, authorize('admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const limit = parseInt(req.query.limit as string) || 10;
    const offset = parseInt(req.query.offset as string) || 0;
    const status = (req.query.status as string) || '';
    const search = (req.query.search as string) || '';

    // Build conditions
    const conditions = [];
    const params: any[] = [];
    let paramCount = 1;

    if (status) {
      conditions.push(`v.status = $${paramCount}`);
      params.push(status);
      paramCount++;
    }

    if (search) {
      conditions.push(`(u.name ILIKE $${paramCount} OR u.email ILIKE $${paramCount})`);
      params.push(`%${search}%`);
      paramCount++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    params.push(limit);
    params.push(offset);

    const kycRes = await query(`
      SELECT
        v.id,
        v.user_id,
        v.status,
        v.documents,
        v.property_data,
        
        
        v.admin_notes,
        v.created_at,
        v.updated_at,
        u.id as user_id,
        u.name,
        u.email,
        u.phone,
        u.role,
        COUNT(DISTINCT p.id)::int as property_count
      FROM verifications v
      JOIN users u ON v.user_id = u.id
      LEFT JOIN properties p ON u.id = p.landlord_id
      ${whereClause}
      GROUP BY v.id, u.id, u.name, u.email, u.phone, u.role
      ORDER BY v.created_at DESC
      LIMIT $${paramCount} OFFSET $${paramCount + 1}
    `, [...params]);

    res.json({
      success: true,
      data: kycRes.rows.map(row => ({
        id: row.id,
        user_id: row.user_id,
        name: row.name,
        email: row.email,
        phone: row.phone,
          avatar: row.avatar,
        role: row.role,
        documents: row.documents,
        property_data: row.property_data,
        status: row.status,
        
        
        admin_notes: row.admin_notes,
        property_count: row.property_count,
        created_at: row.created_at,
        updated_at: row.updated_at,
      }))
    });
  } catch (err) {
    next(err);
  }
});

// PATCH /admin/kyc/:id - Update KYC verification status
router.patch('/kyc/:id', requireAuth, authorize('admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { status, admin_notes } = req.body;

    if (!status || !['approved', 'rejected', 'under_review', 'submitted'].includes(status)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid status. Must be approved, rejected, under_review, or submitted'
      });
    }

    const verificationRecord = await query(`
      SELECT id, user_id FROM verifications WHERE id = $1 LIMIT 1
    `, [id]);

    if (verificationRecord.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'KYC record not found'
      });
    }

    if (status === 'approved' || status === 'rejected') {
      const payload = await finalizeVerificationDecision({
        verificationId: verificationRecord.rows[0].id,
        userId: verificationRecord.rows[0].user_id,
        status: status,
        adminNotes: admin_notes ?? null,
      });

      return res.json({
        success: true,
        data: payload,
      });
    }

    const updateRes = await query(`
      UPDATE verifications
      SET status = $1, admin_notes = $2, updated_at = CURRENT_TIMESTAMP
      WHERE id = $3
      RETURNING *
    `, [status, admin_notes || null, id]);

    res.json({
      success: true,
      data: updateRes.rows[0]
    });
  } catch (err) {
    next(err);
  }
});

// PATCH /admin/properties/:id/status - Update property status
router.patch('/properties/:id/status', requireAuth, authorize('admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const validStatuses = ['pending_review', 'approved', 'rejected', 'available', 'rented', 'maintenance'];
    if (!status || !validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        error: `Invalid status. Must be one of: ${validStatuses.join(', ')}`
      });
    }

    const updateRes = await query(`
      UPDATE properties
      SET status = $1
      WHERE id = $2
      RETURNING *
    `, [status, id]);

    if (updateRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Property not found'
      });
    }

    const property = updateRes.rows[0];

    // Clear property cache since visibility changed
    await cache.del('cache:properties*');
    await cache.del('cache:/api/properties*');

    // Notify the landlord
    if (status === 'approved') {
      const notificationSent = await sendPushToUser(
        property.landlord_id,
        'Property Approved! ??',
        `Your listing "${property.title}" has been approved and is now live on StayNest.`,
        { type: 'property_status', propertyId: id, status: 'approved' }
      );
      console.log(`[AdminPropertyStatus] approval notification userId=${property.landlord_id} sent=${notificationSent} propertyId=${id}`);
    } else if (status === 'rejected') {
      const notificationSent = await sendPushToUser(
        property.landlord_id,
        'Property Requires Revision',
        `Your listing "${property.title}" requires some changes before it can be published.`,
        { type: 'property_status', propertyId: id, status: 'rejected' }
      );
      console.log(`[AdminPropertyStatus] rejection notification userId=${property.landlord_id} sent=${notificationSent} propertyId=${id}`);
    }

    res.json({
      success: true,
      data: property
    });
  } catch (err) {
    next(err);
  }
});


// GET /admin/overview - Dashboard stats
router.get('/overview', requireAuth, authorize('admin'), async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const usersRes = await query(`SELECT COUNT(*)::int as count FROM users`);
    const propsRes = await query(`SELECT COUNT(*)::int as count FROM properties`);
    const pendingKycRes = await query(`SELECT COUNT(*)::int as count FROM verifications WHERE status IN ('submitted', 'under_review')`);
    const revenueRes = await query(`SELECT COALESCE(SUM(total_price), 0)::numeric as total FROM bookings WHERE status IN ('confirmed', 'completed')`);
    const monthlyRevRes = await query(`SELECT COALESCE(SUM(total_price), 0)::numeric as total FROM bookings WHERE status IN ('confirmed', 'completed') AND created_at > now() - interval '30 days'`);
    const chartRes = await query(`
      WITH dates AS (
        SELECT generate_series(CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE, '1 day'::interval)::date AS date
      )
      SELECT to_char(d.date, 'Mon DD') AS label,
             COUNT(DISTINCT u.id)::int AS new_users,
             COUNT(DISTINCT b.id)::int AS new_bookings
      FROM dates d
      LEFT JOIN users u ON DATE(u.created_at) = d.date
      LEFT JOIN bookings b ON DATE(b.created_at) = d.date
      GROUP BY d.date ORDER BY d.date ASC
    `);
    const verificationRes = await query(`
      WITH dates AS (
        SELECT generate_series(CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE, '1 day'::interval)::date AS date
      )
      SELECT to_char(d.date, 'Mon DD') AS label,
             COALESCE((COUNT(*) FILTER (WHERE v.status = 'approved')::numeric / NULLIF(COUNT(v.id), 0)) * 100, 0)::int AS success_rate
      FROM dates d
      LEFT JOIN verifications v ON DATE(v.created_at) = d.date
      GROUP BY d.date ORDER BY d.date ASC
    `);
    const retentionRes = await query(`
      WITH cohorts AS (SELECT id, DATE(created_at) AS signup_date FROM users),
      intervals AS (SELECT unnest(ARRAY[7, 14, 21, 28, 35]) AS day_interval)
      SELECT i.day_interval AS label_day,
             COALESCE((COUNT(DISTINCT e.user_id)::numeric / NULLIF(COUNT(DISTINCT c.id), 0)) * 100, 0)::int AS retention_rate
      FROM intervals i CROSS JOIN cohorts c
      LEFT JOIN engagement_events e ON e.user_id = c.id
        AND DATE(e.created_at) BETWEEN c.signup_date + i.day_interval - 3 AND c.signup_date + i.day_interval + 3
      GROUP BY i.day_interval ORDER BY i.day_interval ASC
    `);
    const cohortRes = await query(`
      SELECT to_char(DATE_TRUNC('month', created_at), 'Mon YYYY') AS cohort,
             COUNT(*) FILTER (WHERE role = 'landlord')::int AS active_landlords
      FROM users GROUP BY DATE_TRUNC('month', created_at)
      ORDER BY DATE_TRUNC('month', created_at) DESC LIMIT 5
    `);
    const locationsRes = await query(`
      SELECT COALESCE(NULLIF(p.city, ''), 'Unknown') AS label, COUNT(*)::int AS value
      FROM engagement_events e JOIN properties p ON p.id = e.property_id
      WHERE e.event_type IN ('property_view', 'property_detail_view')
        AND e.created_at >= CURRENT_DATE - INTERVAL '30 days'
      GROUP BY 1 ORDER BY value DESC LIMIT 5
    `);
    const rejectionRes = await query(`
      SELECT COALESCE(NULLIF(split_part(admin_notes, ':', 1), ''), 'Other') AS label, COUNT(*)::int AS value
      FROM verifications WHERE status = 'rejected'
      GROUP BY 1 ORDER BY value DESC LIMIT 5
    `);
    const eventsRes = await query(`
      SELECT event_type AS label, COUNT(*)::int AS value
      FROM engagement_events WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
      GROUP BY event_type ORDER BY value DESC LIMIT 5
    `);
    const backlogRes = await query(`
      SELECT to_char(DATE(created_at), 'Mon DD') AS label, COUNT(*)::int AS value
      FROM verifications WHERE status IN ('submitted', 'under_review')
      GROUP BY DATE(created_at) ORDER BY DATE(created_at) ASC LIMIT 7
    `);

    res.json({
      success: true,
      data: {
        totalUsers: usersRes.rows[0].count,
        totalProperties: propsRes.rows[0].count,
        pendingVerifications: pendingKycRes.rows[0].count,
        totalRevenue: parseFloat(revenueRes.rows[0].total) || 0,
        monthlyRevenue: parseFloat(monthlyRevRes.rows[0].total) || 0,
        chartData: chartRes.rows,
        backlogData: backlogRes.rows,
        verificationData: verificationRes.rows,
        retentionData: retentionRes.rows,
        cohortData: cohortRes.rows,
        topLocations: locationsRes.rows,
        kycRejections: rejectionRes.rows,
        keyEvents: eventsRes.rows
      }
    });
  } catch (err) {
    next(err);
  }
});

export default router;
