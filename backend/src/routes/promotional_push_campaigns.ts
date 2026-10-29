import { Router, Request, Response, NextFunction } from 'express';
import { pool, query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
import { queuePromotionalCampaign } from '../services/queue.js';
import { recordAdminAudit } from '../services/audit_service.js';
import {
  buildCampaignRecipientQuery,
  hasCampaignAdminRole,
  isEligibleCampaignAvailability,
  normalizeCampaignImageUrl,
  normalizeCampaignAudience,
} from '../services/promotional_campaign_policy.js';

const router = Router();
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function requireCurrentAdmin(req: Request, res: Response, next: NextFunction) {
  try {
    const result = await query('SELECT role, roles FROM users WHERE id = $1 LIMIT 1', [req.auth!.id]);
    const user = result.rows[0] as { role?: string; roles?: string[] } | undefined;
    if (!hasCampaignAdminRole(user)) return res.status(403).json({ error: 'Administrator access is required.' });
    next();
  } catch (error) {
    next(error);
  }
}

async function loadEligibleProperty(propertyId: string, lock = false) {
  if (!UUID_PATTERN.test(propertyId)) return null;
  const result = await query(
    `SELECT p.id, p.title, p.category, p.city, p.town, p.price, p.minimum_stay,
            p.status, p.availability_status, p.image_url
     FROM properties p
     WHERE p.id = $1 AND p.status = 'approved'
       AND lower(coalesce(p.availability_status, '')) IN ('available', 'pending_booking')
     ${lock ? 'FOR SHARE' : ''}`,
    [propertyId],
  );
  const property = result.rows[0];
  return property && isEligibleCampaignAvailability(property.availability_status) ? property : null;
}

async function estimateAudience() {
  const recipientQuery = buildCampaignRecipientQuery();
  const result = await query(`SELECT count(*)::int AS count FROM (${recipientQuery.sql}) eligible`, recipientQuery.params);
  return Number(result.rows[0]?.count ?? 0);
}

async function getCampaignAudienceDiagnostics() {
  const result = await query(`
    SELECT
      count(*)::int AS total_accounts,
      count(*) FILTER (WHERE u.fcm_token IS NOT NULL AND btrim(u.fcm_token) <> '')::int AS accounts_with_token
    FROM users u
  `);
  const values = result.rows[0] ?? {};
  return Object.fromEntries(Object.entries(values).map(([key, value]) => [key, Number(value ?? 0)]));
}

router.use(requireAuth);

router.get('/properties', requireCurrentAdmin, async (req, res, next) => {
  try {
    const search = typeof req.query.search === 'string' ? req.query.search.trim().slice(0, 100) : '';
    const result = await query(
      `SELECT p.id, p.title, p.category, p.city, p.town, p.price, p.minimum_stay,
              p.status, p.availability_status, p.image_url
       FROM properties p
       WHERE p.status = 'approved'
         AND lower(coalesce(p.availability_status, '')) IN ('available', 'pending_booking')
         AND ($1 = '' OR p.title ILIKE '%' || $1 || '%' OR p.city ILIKE '%' || $1 || '%' OR p.town ILIKE '%' || $1 || '%')
       ORDER BY p.published_at DESC NULLS LAST, p.created_at DESC
       LIMIT 50`,
      [search],
    );
    res.json({ data: result.rows.map((property) => {
      const campaignImageUrl = normalizeCampaignImageUrl(property.image_url);
      return {
        ...property,
        campaign_image_url: campaignImageUrl,
        image_valid: campaignImageUrl !== null,
      };
    }) });
  } catch (error) { next(error); }
});

router.post('/estimate', requireCurrentAdmin, async (req, res, next) => {
  try {
    const propertyId = String(req.body?.propertyId ?? '');
    const audience = normalizeCampaignAudience(req.body?.audience ?? {});
    if (!UUID_PATTERN.test(propertyId) || !audience) {
      return res.status(400).json({ error: 'A valid property and audience selection are required.' });
    }
    const property = await loadEligibleProperty(propertyId);
    if (!property) return res.status(404).json({ error: 'This property is not eligible for a campaign.' });
    const count = await estimateAudience();
    const diagnostics = await getCampaignAudienceDiagnostics();
    res.json({ data: {
      estimatedRecipients: count,
      diagnostics,
      audience,
      notes: [
        'All accounts with a registered FCM token are included, regardless of role, suspension status, notification preferences, or saved targeting preferences.',
        'FCM-invalid tokens are cleared after a delivery attempt is rejected.',
      ],
    } });
  } catch (error) { next(error); }
});

router.get('/', requireCurrentAdmin, async (req, res, next) => {
  try {
    const limit = Math.min(Math.max(Number.parseInt(String(req.query.limit ?? '20'), 10) || 20, 1), 100);
    const offset = Math.max(Number.parseInt(String(req.query.offset ?? '0'), 10) || 0, 0);
    const result = await query(
      `SELECT c.*, p.title AS property_title, p.city AS property_city, p.image_url AS current_image_url,
              (SELECT count(*)::int FROM promotional_push_deliveries d WHERE d.campaign_id = c.id AND d.opened_at IS NOT NULL) AS opened_count
       FROM promotional_push_campaigns c
       LEFT JOIN properties p ON p.id = c.property_id
       ORDER BY c.created_at DESC LIMIT $1 OFFSET $2`,
      [limit, offset],
    );
    res.json({ data: result.rows });
  } catch (error) { next(error); }
});

router.get('/:id', requireCurrentAdmin, async (req, res, next) => {
  try {
    if (!UUID_PATTERN.test(req.params.id)) return res.status(400).json({ error: 'Invalid campaign ID.' });
    const result = await query(
      `SELECT c.*, p.title AS property_title, p.city AS property_city,
              (SELECT count(*)::int FROM promotional_push_deliveries d WHERE d.campaign_id = c.id AND d.opened_at IS NOT NULL) AS opened_count
       FROM promotional_push_campaigns c LEFT JOIN properties p ON p.id = c.property_id
       WHERE c.id = $1`,
      [req.params.id],
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Campaign not found.' });
    res.json({ data: result.rows[0] });
  } catch (error) { next(error); }
});

router.post('/', requireCurrentAdmin, async (req, res, next) => {
  const propertyId = String(req.body?.propertyId ?? '');
  const title = typeof req.body?.title === 'string' ? req.body.title.trim() : '';
  const body = typeof req.body?.body === 'string' ? req.body.body.trim() : '';
  const name = typeof req.body?.name === 'string' ? req.body.name.trim() : null;
  const idempotencyKey = String(req.get('Idempotency-Key') ?? req.body?.idempotencyKey ?? '').trim();
  const audience = normalizeCampaignAudience(req.body?.audience ?? {});

  if (!UUID_PATTERN.test(propertyId) || !audience || !idempotencyKey || idempotencyKey.length > 128 ||
      !title || title.length > 80 || !body || body.length > 180 ||
      (name !== null && name.length > 100)) {
    return res.status(400).json({ error: 'Check the property, audience, idempotency key, title (1-80), body (1-180), and campaign name (up to 100 characters).' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const existing = await client.query(
      'SELECT id, status, eligible_count FROM promotional_push_campaigns WHERE admin_id = $1 AND idempotency_key = $2',
      [req.auth!.id, idempotencyKey],
    );
    if (existing.rows[0]) {
      await client.query('COMMIT');
      if (existing.rows[0].status === 'queued') {
        await queuePromotionalCampaign(existing.rows[0].id);
      }
      return res.status(202).json({ data: existing.rows[0], idempotent: true });
    }

    const propertyResult = await client.query(
      `SELECT p.id, p.title, p.category, p.city, p.availability_status, p.image_url
       FROM properties p WHERE p.id = $1 AND p.status = 'approved'
         AND lower(coalesce(p.availability_status, '')) IN ('available', 'pending_booking')
       FOR SHARE`,
      [propertyId],
    );
    const property = propertyResult.rows[0];
    if (!property || !isEligibleCampaignAvailability(property.availability_status)) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'This property is no longer eligible for a campaign.' });
    }
    const imageUrl = normalizeCampaignImageUrl(property.image_url);

    const recipientQuery = buildCampaignRecipientQuery();
    const recipientCountResult = await client.query(
      `SELECT count(*)::int AS count FROM (${recipientQuery.sql}) eligible`,
      recipientQuery.params,
    );
    const eligibleCount = Number(recipientCountResult.rows[0]?.count ?? 0);
    if (eligibleCount === 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'No accounts with a registered FCM token are available.' });
    }

    const campaignResult = await client.query(
      `INSERT INTO promotional_push_campaigns
         (name, admin_id, property_id, title, body, image_url, audience, eligible_count, idempotency_key)
       VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8, $9)
       RETURNING id, status, eligible_count, created_at`,
      [name || null, req.auth!.id, property.id, title, body, imageUrl, JSON.stringify(audience), eligibleCount, idempotencyKey],
    );
    const campaign = campaignResult.rows[0];
    await client.query(
      `INSERT INTO promotional_push_deliveries (campaign_id, user_id)
       SELECT $1, eligible.id FROM (${recipientQuery.sql}) eligible
       ON CONFLICT (campaign_id, user_id) DO NOTHING`,
      [campaign.id, ...recipientQuery.params],
    );
    await client.query('COMMIT');

    try {
      await recordAdminAudit(req, 'promotional_push_campaign_queued', 'promotional_push_campaign', campaign.id, {
        propertyId: property.id,
        eligibleCount,
        audience,
      });
    } catch (auditError) {
      console.error(`[PushCampaign] audit record failed id=${campaign.id}:`, auditError);
    }

    try {
      await queuePromotionalCampaign(campaign.id);
    } catch (queueError) {
      console.error(`[PushCampaign] durable campaign queued for recovery id=${campaign.id}:`, queueError);
    }
    res.status(202).json({ data: campaign });
  } catch (error) {
    await client.query('ROLLBACK').catch(() => undefined);
    if ((error as { code?: string })?.code === '23505') {
      const existing = await query(
        `SELECT id, status, eligible_count FROM promotional_push_campaigns
         WHERE admin_id = $1 AND idempotency_key = $2`,
        [req.auth!.id, idempotencyKey],
      );
      if (existing.rows[0]) {
        return res.status(202).json({ data: existing.rows[0], idempotent: true });
      }
    }
    next(error);
  } finally {
    client.release();
  }
});

export default router;