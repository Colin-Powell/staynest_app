import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, authorize } from '../middleware/auth.js';
const router = Router();
// GET /admin/users - List all users with metadata
router.get('/users', requireAuth, authorize('admin'), async (req, res, next) => {
    try {
        const limit = Math.min(Math.max(Number(req.query.limit) || 10, 1), 100);
        const offset = Math.max(Number(req.query.offset) || 0, 0);
        const search = String(req.query.search || '');
        const role = String(req.query.role || '');
        const conditions = [];
        const params = [];
        let parameter = 1;
        if (role) {
            conditions.push(`u.role = $${parameter++}`);
            params.push(role);
        }
        if (search) {
            conditions.push(`(u.name ILIKE $${parameter} OR u.email ILIKE $${parameter} OR u.phone ILIKE $${parameter})`);
            params.push(`%${search}%`);
            parameter++;
        }
        params.push(limit, offset);
        const usersRes = await query(`
      SELECT u.id, u.name, u.email, u.phone, u.role, u.verified, 'active' as status, u.created_at, u.created_at as updated_at,
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
    }
    catch (err) {
        next(err);
    }
});
// GET /admin/properties - List properties for moderation with metadata
router.get('/properties', requireAuth, authorize('admin'), async (req, res, next) => {
    try {
        const limit = parseInt(req.query.limit) || 10;
        const offset = parseInt(req.query.offset) || 0;
        const status = req.query.status || '';
        const search = req.query.search || '';
        // Build conditions
        const conditions = [];
        const params = [];
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
                created_at: row.created_at,
                landlord_id: row.landlord_id,
                landlord_name: row.landlord_name,
                landlord_email: row.landlord_email,
                landlord_verified: row.landlord_verified,
            }))
        });
    }
    catch (err) {
        next(err);
    }
});
// GET /admin/kyc - List KYC verifications for review with metadata
router.get('/kyc', requireAuth, authorize('admin'), async (req, res, next) => {
    try {
        const limit = parseInt(req.query.limit) || 10;
        const offset = parseInt(req.query.offset) || 0;
        const status = req.query.status || '';
        const search = req.query.search || '';
        // Build conditions
        const conditions = [];
        const params = [];
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
        v.document_type,
        v.document_url,
        v.document_number,
        v.selfie_url,
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
                role: row.role,
                document_type: row.document_type,
                document_url: row.document_url,
                document_number: row.document_number,
                selfie_url: row.selfie_url,
                admin_notes: row.admin_notes,
                property_count: row.property_count,
                created_at: row.created_at,
            }))
        });
    }
    catch (err) {
        next(err);
    }
});
// PATCH /admin/kyc/:id - Update KYC verification status
router.patch('/kyc/:id', requireAuth, authorize('admin'), async (req, res, next) => {
    try {
        const { id } = req.params;
        const { status, admin_notes } = req.body;
        if (!status || !['approved', 'rejected', 'under_review', 'submitted'].includes(status)) {
            return res.status(400).json({
                success: false,
                error: 'Invalid status. Must be approved, rejected, under_review, or submitted'
            });
        }
        const updateRes = await query(`
      UPDATE verifications
      SET status = $1, admin_notes = $2, updated_at = CURRENT_TIMESTAMP
      WHERE id = $3
      RETURNING *
    `, [status, admin_notes || null, id]);
        if (updateRes.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'KYC record not found'
            });
        }
        res.json({
            success: true,
            data: updateRes.rows[0]
        });
    }
    catch (err) {
        next(err);
    }
});
// PATCH /admin/properties/:id/status - Update property status
router.patch('/properties/:id/status', requireAuth, authorize('admin'), async (req, res, next) => {
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
        res.json({
            success: true,
            data: updateRes.rows[0]
        });
    }
    catch (err) {
        next(err);
    }
});
// GET /admin/overview - Dashboard stats
router.get('/overview', requireAuth, authorize('admin'), async (_req, res, next) => {
    try {
        const usersRes = await query(`SELECT COUNT(*)::int as count FROM users`);
        const propsRes = await query(`SELECT COUNT(*)::int as count FROM properties`);
        const pendingKycRes = await query(`SELECT COUNT(*)::int as count FROM verifications WHERE status IN ('submitted', 'under_review')`);
        const revenueRes = await query(`SELECT COALESCE(SUM(total_price), 0)::numeric as total FROM bookings WHERE status IN ('confirmed', 'completed')`);
        const monthlyRevRes = await query(`SELECT COALESCE(SUM(total_price), 0)::numeric as total FROM bookings WHERE status IN ('confirmed', 'completed') AND created_at > now() - interval '30 days'`);
        res.json({
            success: true,
            data: {
                totalUsers: usersRes.rows[0].count,
                totalProperties: propsRes.rows[0].count,
                pendingVerifications: pendingKycRes.rows[0].count,
                totalRevenue: parseFloat(revenueRes.rows[0].total) || 0,
                monthlyRevenue: parseFloat(monthlyRevRes.rows[0].total) || 0,
                chartData: [
                    { "day": "Mon", "users": 12, "bookings": 4 },
                    { "day": "Tue", "users": 19, "bookings": 6 },
                    { "day": "Wed", "users": 15, "bookings": 8 },
                    { "day": "Thu", "users": 22, "bookings": 5 },
                    { "day": "Fri", "users": 30, "bookings": 12 },
                    { "day": "Sat", "users": 45, "bookings": 25 },
                    { "day": "Sun", "users": 40, "bookings": 20 }
                ],
                backlogData: [
                    { "hour": "00:00", "count": 2 },
                    { "hour": "04:00", "count": 1 },
                    { "hour": "08:00", "count": 5 },
                    { "hour": "12:00", "count": 12 },
                    { "hour": "16:00", "count": 8 },
                    { "hour": "20:00", "count": 3 }
                ],
                verificationData: [
                    { "date": "Week 1", "rate": 85 },
                    { "date": "Week 2", "rate": 82 },
                    { "date": "Week 3", "rate": 90 },
                    { "date": "Week 4", "rate": 95 }
                ],
                retentionData: [
                    { "month": "Jan", "rate": 40 },
                    { "month": "Feb", "rate": 45 },
                    { "month": "Mar", "rate": 42 },
                    { "month": "Apr", "rate": 50 },
                    { "month": "May", "rate": 55 },
                    { "month": "Jun", "rate": 60 }
                ],
                cohortData: [
                    { "cohort": "2026-Q1", "m1": 100, "m2": 80, "m3": 75, "m4": 60, "m5": 55 },
                    { "cohort": "2026-Q2", "m1": 100, "m2": 85, "m3": 80, "m4": 70, "m5": 65 }
                ]
            }
        });
    }
    catch (err) {
        next(err);
    }
});
export default router;
//# sourceMappingURL=admin.js.map