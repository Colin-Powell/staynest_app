import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, authorize } from '../middleware/auth.js';
import { sendPushToUser } from '../services/firebase.js';
const router = Router();
export const createVerificationHandler = async (req, res, next) => {
    try {
        const { documents, property } = req.body;
        if (!documents || !property) {
            return res.status(400).json({ error: 'Documents and property data are required.' });
        }
        const requiredDocuments = [
            'id_photo_front', 'id_photo_back', 'selfie',
            'proof_of_address', 'utility_bill', 'property_photos',
        ];
        const missingDocuments = requiredDocuments.filter((key) => typeof documents[key] !== 'string' || documents[key].trim().length === 0);
        if (missingDocuments.length > 0) {
            return res.status(400).json({
                error: 'All required verification documents must be uploaded before submission.',
                missing_documents: missingDocuments,
            });
        }
        // Every submission remains pending until an authorized admin reviews it.
        const initialStatus = 'submitted';
        const result = await query(`INSERT INTO verifications (user_id, status, documents, property_data)
       VALUES ($1, $2, $3::jsonb, $4::jsonb)
       RETURNING id, user_id, status, documents, property_data, admin_notes, created_at, updated_at`, [req.auth.id, initialStatus, JSON.stringify(documents), JSON.stringify(property)]);
        return res.status(201).json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
};
router.post('/', requireAuth, createVerificationHandler);
// Get current user's latest verification
router.get('/me', requireAuth, async (req, res, next) => {
    try {
        const existing = await query(`SELECT id, user_id, status, documents FROM verifications WHERE id = $1`, [req.params.id]);
        if (existing.rowCount === 0) {
            return res.status(404).json({ error: 'Verification not found.' });
        }
        const current = existing.rows[0];
        if (status === 'approved' && current.status !== 'submitted') {
            return res.status(409).json({ error: 'Only submitted verifications can be approved.' });
        }
        if (status === 'approved') {
            const requiredDocuments = [
                'id_photo_front', 'id_photo_back', 'selfie',
                'proof_of_address', 'utility_bill', 'property_photos',
            ];
            const documents = current.documents ?? {};
            const complete = requiredDocuments.every((key) => typeof documents[key] === 'string' && documents[key].trim().length > 0);
            if (!complete) {
                return res.status(422).json({ error: 'Approval requires a complete document submission.' });
            }
        }
        const result = await query(`SELECT id, user_id, status, documents, property_data, admin_notes, created_at, updated_at
       FROM verifications
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 1`, [req.auth.id]);
        if (result.rowCount === 0) {
            return res.json({ data: null });
        }
        return res.json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
// Admin: Get all verifications with optional status filter
router.get('/admin/all', requireAuth, authorize('admin'), async (req, res, next) => {
    try {
        const status = typeof req.query.status === 'string' ? req.query.status.trim() : undefined;
        const offset = parseInt(req.query.offset) || 0;
        const limit = Math.min(parseInt(req.query.limit) || 50, 100);
        const conditions = [];
        const params = [];
        if (status) {
            params.push(status);
            conditions.push(`v.status = $${params.length}`);
        }
        const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
        const result = await query(`SELECT v.id, v.user_id, v.status, v.documents, v.property_data, v.admin_notes, v.created_at, v.updated_at,
              u.name AS user_name, u.email AS user_email, u.phone AS user_phone
       FROM verifications v LEFT JOIN users u ON u.id = v.user_id ${whereClause}
       ORDER BY v.created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`, [...params, limit, offset]);
        const countRes = await query(`SELECT COUNT(*) as total FROM verifications v ${whereClause}`, params);
        return res.json({ data: result.rows, total: countRes.rows[0]?.total || 0, offset, limit });
    }
    catch (error) {
        next(error);
    }
});
// Admin: Approve or reject verification
router.put('/:id', requireAuth, authorize('admin'), async (req, res, next) => {
    try {
        const { status, admin_notes } = req.body;
        if (!status || !['approved', 'rejected'].includes(status)) {
            return res.status(400).json({ error: 'Status must be "approved" or "rejected".' });
        }
        const result = await query(`UPDATE verifications SET status = $1, admin_notes = $2, updated_at = now() WHERE id = $3
       RETURNING id, user_id, status, documents, property_data, admin_notes, created_at, updated_at`, [status, admin_notes || null, req.params.id]);
        if (status === 'approved') {
            await query(`UPDATE users SET verified = true WHERE id = $1`, [result.rows[0].user_id]);
            await sendPushToUser(result.rows[0].user_id, '? Verification Approved', 'Your landlord verification was approved! You can now list properties.', { type: 'verification_approved' });
        }
        else if (status === 'rejected') {
            await query(`UPDATE users SET verified = false WHERE id = $1`, [result.rows[0].user_id]);
            await sendPushToUser(result.rows[0].user_id, '? Verification Rejected', 'Your landlord verification was rejected. Please check the notes.', { type: 'verification_rejected' });
        }
        return res.json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=verifications.js.map