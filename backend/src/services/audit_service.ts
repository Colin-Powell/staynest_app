import { Request } from 'express';
import { query } from '../db.js';

export async function recordAdminAudit(
  req: Request,
  action: string,
  entityType: string,
  entityId: string | null,
  metadata: Record<string, unknown> = {},
) {
  await query(
    `INSERT INTO admin_audit_logs
      (admin_id, action, entity_type, entity_id, request_id, ip_address, metadata)
     VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)`,
    [
      req.auth?.id ?? null,
      action,
      entityType,
      entityId,
      req.headers['x-request-id']?.toString() ?? null,
      req.ip || null,
      JSON.stringify(metadata),
    ],
  );
}