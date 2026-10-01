import { Router, Request, Response, NextFunction } from 'express';
import { pool, query } from '../db.js';
import { requireAuth, authorize } from '../middleware/auth.js';
import { queueUserPush } from '../services/queue.js';
import { sendAlertEmail, sendLandlordVerificationDecisionEmail } from '../services/email.js';

const router = Router();

export const REQUIRED_VERIFICATION_DOCUMENTS = [
  'id_photo_front',
  'id_photo_back',
  'selfie',
  'lease_agreement',
] as const;

const DOCUMENT_ALIASES: Record<string, string[]> = {
  id_photo_front: ['id_photo_front', 'idPhotoFront'],
  id_photo_back: ['id_photo_back', 'idPhotoBack'],
  selfie: ['selfie', 'selfieUrl'],
  lease_agreement: ['lease_agreement', 'leaseAgreement', 'leaseAgreementUrl'],
  proof_of_address: ['proof_of_address', 'proofOfAddressUrl'],
  utility_bill: ['utility_bill', 'utilityBillUrl'],
};

const normalizeVerificationDocuments = (documents: unknown): Record<string, string> => {
  const normalized: Record<string, string> = {};
  if (!documents || typeof documents !== 'object') {
    return normalized;
  }

  const raw = documents as Record<string, any>;

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

export const hasRequiredVerificationDocuments = (documents: Record<string, any> | undefined) => {
  const normalizedDocuments = normalizeVerificationDocuments(documents);
  return REQUIRED_VERIFICATION_DOCUMENTS.every(
    (key) => typeof normalizedDocuments[key] === 'string' && normalizedDocuments[key].trim().length > 0,
  );
};

export async function finalizeVerificationDecision({
  verificationId,
  userId,
  status,
  adminNotes,
  adminId,
}: {
  verificationId: string;
  userId: string;
  status: 'approved' | 'rejected';
  adminNotes?: string | null;
  adminId?: string;
}) {
  const client = await pool.connect();
  let verification: Record<string, any>;
  let user: Record<string, any>;
  let didTransition = false;
  try {
    await client.query('BEGIN');
    const accountResult = await client.query(
      'SELECT id FROM users WHERE id = $1 FOR UPDATE',
      [userId],
    );
    if (!accountResult.rows[0]) {
      throw Object.assign(new Error('Account not found.'), { statusCode: 404 });
    }
    const currentResult = await client.query(
      `SELECT id, user_id, status, documents FROM verifications WHERE id = $1 FOR UPDATE`,
      [verificationId],
    );
    const current = currentResult.rows[0];
    if (!current || current.user_id !== userId) {
      throw Object.assign(new Error('Verification record not found.'), {
        statusCode: 404,
      });
    }
    if (current.status === 'cancelled') {
      throw Object.assign(
        new Error('Cancelled applications cannot be approved or rejected.'),
        { statusCode: 409 },
      );
    }
    if (status === 'approved' &&
        !hasRequiredVerificationDocuments(current.documents as Record<string, any> | undefined)) {
      throw Object.assign(
        new Error('Required identity and ownership documents must be present before approval.'),
        { statusCode: 409 },
      );
    }
    if (current.status === status) {
      const existing = await client.query(
        `SELECT id, user_id, status, documents, property_data, admin_notes,
                created_at, updated_at, submitted_at, cancelled_at
         FROM verifications WHERE id = $1`,
        [verificationId],
      );
      verification = existing.rows[0];
      const existingUser = await client.query(
        'SELECT id, name, email FROM users WHERE id = $1',
        [userId],
      );
      user = existingUser.rows[0];
      await client.query('COMMIT');
    } else {
      didTransition = true;
      if (!['submitted', 'under_review', 'pending_review', 'manual_review', 'more_info_required'].includes(current.status)) {
        throw Object.assign(
          new Error(`Application in ${current.status} state cannot be ${status}.`),
          { statusCode: 409 },
        );
      }

      const verificationResult = await client.query(
        `UPDATE verifications
         SET status = $1, admin_notes = $2, updated_at = now()
         WHERE id = $3
         RETURNING id, user_id, status, documents, property_data, admin_notes,
                   created_at, updated_at, submitted_at, cancelled_at`,
        [status, adminNotes ?? null, verificationId],
      );
      verification = verificationResult.rows[0];

      if (status === 'approved') {
        await client.query(
          `UPDATE users
           SET landlord_verified = true,
               roles = CASE
                 WHEN 'landlord' = ANY(roles) THEN roles
                 ELSE array_append(roles, 'landlord')
               END
           WHERE id = $1`,
          [userId],
        );
      }

      const userResult = await client.query(
        'SELECT id, name, email FROM users WHERE id = $1 LIMIT 1',
        [userId],
      );
      user = userResult.rows[0];
      if (adminId) {
        await client.query(
          `INSERT INTO admin_audit_logs (admin_id, action, entity_type, entity_id, metadata)
           VALUES ($1, $2, 'landlord_verification', $3, $4::jsonb)`,
          [adminId, `verification_${status}`, verificationId, JSON.stringify({ userId, adminNotes: adminNotes ?? null })],
        );
      }
      await client.query('COMMIT');
    }
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  if (didTransition && user?.email) {
    try {
      await sendLandlordVerificationDecisionEmail(user.email, status, user.name, adminNotes ?? undefined);
    } catch (emailError) {
      console.error('Failed to send landlord verification email:', emailError);
    }
  }

  try {
    if (status === 'approved') {
      await queueUserPush(userId, 'Verification Approved', 'Your host verification was approved. You can now switch to the landlord portal and list properties.', { type: 'verification_approved', verificationId });
    } else {
      await queueUserPush(userId, 'Verification Update', adminNotes || 'Your host application was not approved. Review the reason and reapply if permitted.', { type: 'verification_rejected', verificationId });
    }
  } catch (notificationError) {
    console.error('Failed to queue landlord verification notification:', notificationError);
  }

  return verification;
}

export const createVerificationHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const account = await query(
      'SELECT verified, landlord_verified FROM users WHERE id = $1 LIMIT 1',
      [req.auth!.id],
    );
    if (account.rows[0]?.verified !== true) {
      return res.status(403).json({ error: 'Verify your email before submitting a host application.' });
    }
    if (account.rows[0]?.landlord_verified === true) {
      return res.status(409).json({ error: 'Your host application is already approved.' });
    }

    const body = (req.body ?? {}) as Record<string, any>;
    const documentsInput = body.documents ?? body.property_data?.documents ?? {};
    const propertyInput = body.property ?? body.property_data ?? {};
    const documents = normalizeVerificationDocuments(documentsInput);

    if (!documents || Object.keys(documents).length === 0) {
      return res.status(400).json({ error: 'Verification documents are required.' });
    }

    const missingDocuments = REQUIRED_VERIFICATION_DOCUMENTS.filter(
      (key) => typeof documents[key] !== 'string' || documents[key].trim().length === 0,
    );

    if (missingDocuments.length > 0) {
      return res.status(400).json({
        error: 'All required verification documents must be uploaded before submission.',
        missing_documents: missingDocuments,
      });
    }

    const client = await pool.connect();
    let resultRow: Record<string, any>;
    try {
      await client.query('BEGIN');
      const lockedAccount = await client.query(
        'SELECT verified, landlord_verified FROM users WHERE id = $1 FOR UPDATE',
        [req.auth!.id],
      );
      if (lockedAccount.rows[0]?.verified !== true) {
        await client.query('ROLLBACK');
        return res.status(403).json({ error: 'Verify your email before submitting a host application.' });
      }
      if (lockedAccount.rows[0]?.landlord_verified === true) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Your host application is already approved.' });
      }
      const activeVerification = await client.query(
        `SELECT id, status FROM verifications
         WHERE user_id = $1
           AND status IN ('submitted', 'under_review', 'pending_review', 'manual_review')
         ORDER BY created_at DESC LIMIT 1 FOR UPDATE`,
        [req.auth!.id],
      );
      if (activeVerification.rows[0]) {
        await client.query('ROLLBACK');
        return res.status(409).json({
          error: 'You already have an active host application.',
          current_status: activeVerification.rows[0].status,
          verification_id: activeVerification.rows[0].id,
        });
      }

      const draft = await client.query(
        `SELECT id, status FROM verifications
         WHERE user_id = $1 AND status IN ('draft', 'more_info_required')
         ORDER BY created_at DESC LIMIT 1 FOR UPDATE`,
        [req.auth!.id],
      );
      const draftRecord = draft.rows[0];
      const submitted = await client.query(
        draftRecord
          ? `UPDATE verifications
             SET status = 'submitted', documents = $1::jsonb, property_data = $2::jsonb,
                 admin_notes = CASE WHEN status = 'more_info_required' THEN admin_notes ELSE NULL END,
                 submitted_at = now(), updated_at = now(), reminder_stage = 2
             WHERE id = $3
             RETURNING id, user_id, status, documents, property_data, admin_notes,
                       created_at, updated_at, submitted_at, cancelled_at`
          : `INSERT INTO verifications (user_id, status, documents, property_data, submitted_at, reminder_stage)
             VALUES ($3, 'submitted', $1::jsonb, $2::jsonb, now(), 2)
             RETURNING id, user_id, status, documents, property_data, admin_notes,
                       created_at, updated_at, submitted_at, cancelled_at`,
        draftRecord
          ? [JSON.stringify(documents), JSON.stringify(propertyInput), draftRecord.id]
          : [JSON.stringify(documents), JSON.stringify(propertyInput), req.auth!.id],
      );
      resultRow = submitted.rows[0];
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

    const userResult = await query(
      `SELECT id, name, email FROM users WHERE id = $1 LIMIT 1`,
      [req.auth!.id],
    );

    const user = userResult.rows[0];
    if (user?.email) {
      try {
        await sendAlertEmail(
          user.email,
          'StayNest landlord verification submitted',
          `Hi ${user.name || 'Landlord'},\n\nYour landlord verification documents have been submitted successfully. Our team will review them shortly and notify you once a decision is made.\n\nWarm regards,\nThe StayNest Team`,
          `<p>Hi ${user.name || 'Landlord'},</p><p>Your landlord verification documents have been submitted successfully.</p><p>Our team will review them shortly and notify you once a decision is made.</p><p>Warm regards,<br>The StayNest Team</p>`,
        );
      } catch (emailError) {
        console.error('Failed to send landlord verification submission email:', emailError);
      }
    }

    try {
      await queueUserPush(req.auth!.id, 'Host application submitted', 'Your verification is submitted and awaiting review. We will notify you when its status changes.', { type: 'host_application_submitted', verificationId: resultRow.id });
    } catch (notificationError) {
      console.error('Failed to queue host application submission notification:', notificationError);
    }

    return res.status(201).json({ data: resultRow });
  } catch (error) {
    next(error);
  }
};

router.post('/', requireAuth, createVerificationHandler);

router.post('/draft', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  const client = await pool.connect();
  try {
    const body = (req.body ?? {}) as Record<string, any>;
    const documents = normalizeVerificationDocuments(body.documents ?? {});
    const propertyData = body.property ?? {};
    await client.query('BEGIN');
    const account = await client.query(
      'SELECT verified, landlord_verified FROM users WHERE id = $1 FOR UPDATE',
      [req.auth!.id],
    );
    if (account.rows[0]?.verified !== true) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Verify your email before starting a host application.' });
    }
    if (account.rows[0]?.landlord_verified === true) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Your host application is already approved.' });
    }
    const active = await client.query(
      `SELECT id, status FROM verifications
      WHERE user_id = $1 AND status IN ('submitted', 'under_review', 'pending_review', 'manual_review')
       ORDER BY created_at DESC LIMIT 1`,
      [req.auth!.id],
    );
    if (active.rows[0]) {
      await client.query('ROLLBACK');
      return res.status(409).json({
        error: 'Your host application is already awaiting review.',
        current_status: active.rows[0].status,
        verification_id: active.rows[0].id,
      });
    }
    const existing = await client.query(
      `SELECT id, status FROM verifications
       WHERE user_id = $1 AND status IN ('draft', 'more_info_required')
       ORDER BY created_at DESC LIMIT 1 FOR UPDATE`,
      [req.auth!.id],
    );
    const current = existing.rows[0];
    const result = current
      ? await client.query(
          `UPDATE verifications
           SET status = 'draft', documents = COALESCE(documents, '{}'::jsonb) || $1::jsonb,
               property_data = COALESCE(property_data, '{}'::jsonb) || $2::jsonb,
               updated_at = now(), reminder_stage = 0, reminder_sent_at = NULL
           WHERE id = $3
           RETURNING id, user_id, status, documents, property_data, admin_notes,
                     created_at, updated_at, submitted_at, cancelled_at, reminder_stage`,
          [JSON.stringify(documents), JSON.stringify(propertyData), current.id],
        )
      : await client.query(
          `INSERT INTO verifications (user_id, status, documents, property_data)
           VALUES ($1, 'draft', $2::jsonb, $3::jsonb)
           RETURNING id, user_id, status, documents, property_data, admin_notes,
                     created_at, updated_at, submitted_at, cancelled_at, reminder_stage`,
          [req.auth!.id, JSON.stringify(documents), JSON.stringify(propertyData)],
        );
    await client.query('COMMIT');
    return res.json({ data: result.rows[0] });
  } catch (error) {
    await client.query('ROLLBACK');
    return next(error);
  } finally {
    client.release();
  }
});

router.post('/cancel', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      `UPDATE verifications
       SET status = 'cancelled', cancelled_at = now(), updated_at = now()
       WHERE id = (
         SELECT id FROM verifications
         WHERE user_id = $1 AND status IN ('draft', 'submitted', 'under_review', 'pending_review', 'manual_review', 'more_info_required')
         ORDER BY created_at DESC LIMIT 1
       )
       RETURNING id, user_id, status, admin_notes, created_at, updated_at, submitted_at, cancelled_at`,
      [req.auth!.id],
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'No active host application found.' });
    return res.json({ data: result.rows[0] });
  } catch (error) {
    return next(error);
  }
});

router.post('/dismiss-reminder', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      `UPDATE verifications
       SET reminder_stage = 2, reminder_sent_at = now(), updated_at = now()
       WHERE id = (
         SELECT id FROM verifications
         WHERE user_id = $1 AND status = 'draft'
         ORDER BY created_at DESC LIMIT 1
       )
       RETURNING id, status, reminder_stage, updated_at`,
      [req.auth!.id],
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'No incomplete host application found.' });
    return res.json({ data: result.rows[0] });
  } catch (error) {
    return next(error);
  }
});

// Get current user's latest verification
router.get('/me', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
            `SELECT id, user_id, status, documents, property_data, admin_notes, created_at, updated_at,
              submitted_at, cancelled_at, reminder_stage
       FROM verifications
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 1`,
      [req.auth!.id],
    );

    if (result.rowCount === 0) {
      return res.json({ data: null });
    }

    return res.json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

// Admin: Get all verifications with optional status filter
router.get('/admin/all', requireAuth, authorize('admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const status = typeof req.query.status === 'string' ? req.query.status.trim() : undefined;
    const offset = parseInt(req.query.offset as string) || 0;
    const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);
    const conditions: string[] = [];
    const params: any[] = [];
    if (status) {
      params.push(status);
      conditions.push(`v.status = $${params.length}`);
    }
    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    const result = await query(
      `SELECT v.id, v.user_id, v.status, v.documents, v.property_data, v.admin_notes, v.created_at, v.updated_at,
              u.name AS user_name, u.email AS user_email, u.phone AS user_phone
       FROM verifications v LEFT JOIN users u ON u.id = v.user_id ${whereClause}
       ORDER BY v.created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
      [...params, limit, offset],
    );
    const countRes = await query(`SELECT COUNT(*) as total FROM verifications v ${whereClause}`, params);
    return res.json({ data: result.rows, total: countRes.rows[0]?.total || 0, offset, limit });
  } catch (error) {
    next(error);
  }
});

// Admin: Approve or reject verification
router.put('/:id', requireAuth, authorize('admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { status, admin_notes } = req.body as { status?: string; admin_notes?: string };
    if (!status || !['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ error: 'Status must be "approved" or "rejected".' });
    }

    const verificationRecord = await query(
      `SELECT id, user_id FROM verifications WHERE id = $1 LIMIT 1`,
      [req.params.id],
    );

    if (verificationRecord.rowCount === 0) {
      return res.status(404).json({ error: 'Verification record not found.' });
    }

    const payload = await finalizeVerificationDecision({
      verificationId: verificationRecord.rows[0].id,
      userId: verificationRecord.rows[0].user_id,
      status: status as 'approved' | 'rejected',
      adminNotes: admin_notes,
      adminId: req.auth!.id,
    });

    return res.json({ data: payload });
  } catch (error) {
    next(error);
  }
});

export default router;

