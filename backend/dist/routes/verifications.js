import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, authorize } from '../middleware/auth.js';
import { queueUserPush } from '../services/queue.js';
import { sendLandlordVerificationDecisionEmail } from '../services/email.js';
const router = Router();
export const REQUIRED_VERIFICATION_DOCUMENTS = [
    'id_photo_front',
    'id_photo_back',
    'selfie',
];
const DOCUMENT_ALIASES = {
    id_photo_front: ['id_photo_front', 'idPhotoFront'],
    id_photo_back: ['id_photo_back', 'idPhotoBack'],
    selfie: ['selfie', 'selfieUrl'],
};
const normalizeVerificationDocuments = (documents) => {
    const normalized = {};
    if (!documents || typeof documents !== 'object') {
        return normalized;
    }
    const raw = documents;
    for (const [canonicalKey, aliases] of Object.entries(DOCUMENT_ALIASES)) {
        const value = aliases
            .map((key) => raw[key])
            .find((candidate) => typeof candidate === 'string' && candidate.trim().length > 0);
        if (typeof value === 'string' && value.trim().length > 0) {
            normalized[canonicalKey] = value.trim();
        }
    }
    return normalized;
};
export const hasRequiredVerificationDocuments = (documents) => {
    const normalizedDocuments = normalizeVerificationDocuments(documents);
    return REQUIRED_VERIFICATION_DOCUMENTS.every((key) => typeof normalizedDocuments[key] === 'string' && normalizedDocuments[key].trim().length > 0);
};
export async function finalizeVerificationDecision({ verificationId, userId, status, adminNotes, }) {
    const verificationResult = await query(`UPDATE verifications
     SET status = $1, admin_notes = $2, updated_at = now()
     WHERE id = $3
     RETURNING id, user_id, status, documents, property_data, admin_notes, created_at, updated_at`, [status, adminNotes ?? null, verificationId]);
    if (verificationResult.rowCount === 0) {
        throw new Error('Verification record not found');
    }
    const userResult = await query(`SELECT id, name, email, role, verified FROM users WHERE id = $1 LIMIT 1`, [userId]);
    const user = userResult.rows[0];
    const isApproved = status === 'approved';
    await query(`UPDATE users SET verified = $1 WHERE id = $2`, [isApproved, userId]);
    if (user?.email) {
        try {
            await sendLandlordVerificationDecisionEmail(user.email, status, user.name, adminNotes ?? undefined);
        }
        catch (emailError) {
            console.error('Failed to send landlord verification email:', emailError);
        }
    }
    if (isApproved) {
        await queueUserPush(userId, '✅ Verification Approved', 'Your landlord verification was approved! You can now list properties.', { type: 'verification_approved' });
    }
    else {
        await queueUserPush(userId, '⚠️ Verification Update', 'Your landlord verification was processed. Please review the notes and resubmit if needed.', { type: 'verification_rejected' });
    }
    return verificationResult.rows[0];
}
export const createVerificationHandler = async (req, res, next) => {
    try {
        const body = (req.body ?? {});
        const documentsInput = body.documents ?? body.property_data?.documents ?? {};
        const propertyInput = body.property ?? body.property_data ?? {};
        const documents = normalizeVerificationDocuments(documentsInput);
        if (!documents || Object.keys(documents).length === 0) {
            return res.status(400).json({ error: 'Verification documents are required.' });
        }
        const missingDocuments = REQUIRED_VERIFICATION_DOCUMENTS.filter((key) => typeof documents[key] !== 'string' || documents[key].trim().length === 0);
        if (missingDocuments.length > 0) {
            return res.status(400).json({
                error: 'All required verification documents must be uploaded before submission.',
                missing_documents: missingDocuments,
            });
        }
        const initialStatus = 'submitted';
        const result = await query(`INSERT INTO verifications (user_id, status, documents, property_data)
       VALUES ($1, $2, $3::jsonb, $4::jsonb)
       RETURNING id, user_id, status, documents, property_data, admin_notes, created_at, updated_at`, [req.auth.id, initialStatus, JSON.stringify(documents), JSON.stringify(propertyInput)]);
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
        const verificationRecord = await query(`SELECT id, user_id FROM verifications WHERE id = $1 LIMIT 1`, [req.params.id]);
        if (verificationRecord.rowCount === 0) {
            return res.status(404).json({ error: 'Verification record not found.' });
        }
        const payload = await finalizeVerificationDecision({
            verificationId: verificationRecord.rows[0].id,
            userId: verificationRecord.rows[0].user_id,
            status: status,
            adminNotes: admin_notes,
        });
        return res.json({ data: payload });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=verifications.js.map