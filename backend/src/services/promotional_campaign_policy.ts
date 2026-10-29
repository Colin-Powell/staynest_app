import { env } from '../config.js';

export type CampaignAudience = Record<string, never>;

const ADMIN_ROLES = new Set(['admin', 'super_admin', 'administrator']);

export function hasCampaignAdminRole(user: { role?: string; roles?: string[] } | undefined): boolean {
  return !!user && (
    ADMIN_ROLES.has(String(user.role ?? '').toLowerCase()) ||
    (user.roles ?? []).some((role) => ADMIN_ROLES.has(String(role).toLowerCase()))
  );
}

export function normalizeCampaignAudience(value: unknown): CampaignAudience | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const audience = value as Record<string, unknown>;
  if (Object.keys(audience).length > 0) return null;
  return {};
}

export function isEligibleCampaignAvailability(value: unknown): boolean {
  return new Set(['available', 'pending_booking']).has(
    String(value ?? '').trim().toLowerCase(),
  );
}

export function normalizeCampaignImageUrl(
  value: unknown,
  cloudName = env.cloudinaryCloudName,
): string | null {
  if (typeof value !== 'string' || value.trim().length === 0 || value.length > 2048) return null;
  const image = value.trim();
  try {
    const url = new URL(image);
    if (cloudName &&
      (url.protocol === 'https:' || url.protocol === 'http:') &&
        url.hostname === 'res.cloudinary.com' &&
      url.pathname.startsWith(`/${cloudName}/image/upload/`)) {
      url.protocol = 'https:';
      return url.toString();
    }
    return null;
  } catch {
    if (!cloudName || image.startsWith('/') || image.includes('..') ||
        !/^[A-Za-z0-9_./-]+$/.test(image) || !image.includes('/')) {
      return null;
    }
    const publicId = image.includes('.') ? image : `${image}.jpg`;
    return `https://res.cloudinary.com/${cloudName}/image/upload/${publicId}`;
  }
}

export function isApprovedCampaignImage(
  value: unknown,
  cloudName = env.cloudinaryCloudName,
): value is string {
  return normalizeCampaignImageUrl(value, cloudName) !== null;
}

export function buildCampaignRecipientQuery() {
  return {
    sql: "SELECT DISTINCT u.id FROM users u WHERE u.fcm_token IS NOT NULL AND btrim(u.fcm_token) <> '' ORDER BY u.id",
    params: [],
  };
}