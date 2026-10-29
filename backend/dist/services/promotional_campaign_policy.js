import { env } from '../config.js';
const ADMIN_ROLES = new Set(['admin', 'super_admin', 'administrator']);
export function hasCampaignAdminRole(user) {
    return !!user && (ADMIN_ROLES.has(String(user.role ?? '').toLowerCase()) ||
        (user.roles ?? []).some((role) => ADMIN_ROLES.has(String(role).toLowerCase())));
}
export function normalizeCampaignAudience(value) {
    if (!value || typeof value !== 'object' || Array.isArray(value))
        return null;
    const audience = value;
    if (Object.keys(audience).some((key) => !['location', 'propertyType'].includes(key)))
        return null;
    if (Object.values(audience).some((filter) => typeof filter !== 'boolean'))
        return null;
    return {
        location: audience.location === true,
        propertyType: audience.propertyType === true,
    };
}
export function isEligibleCampaignAvailability(value) {
    return new Set(['available', 'pending_booking']).has(String(value ?? '').trim().toLowerCase());
}
export function isApprovedCampaignImage(value, cloudName = env.cloudinaryCloudName) {
    if (typeof value !== 'string' || value.length > 2048 || !cloudName)
        return false;
    try {
        const url = new URL(value);
        return url.protocol === 'https:' &&
            url.hostname === 'res.cloudinary.com' &&
            url.pathname.startsWith(`/${cloudName}/image/upload/`);
    }
    catch {
        return false;
    }
}
export function buildCampaignRecipientQuery(property, audience) {
    const conditions = [
        "lower(coalesce(u.role, '')) = 'tenant'",
        'u.is_suspended = false',
        "NOT (coalesce(u.roles, '{}'::text[]) && ARRAY['landlord', 'host', 'admin', 'super_admin', 'administrator']::text[])",
        "u.fcm_token IS NOT NULL AND btrim(u.fcm_token) <> ''",
        "u.settings->>'promotional_push' = 'true'",
        "u.settings->>'push_permission_granted' = 'true'",
        "u.settings->>'push' IS DISTINCT FROM 'false'",
        "u.settings->'notifications'->>'push_messages' IS DISTINCT FROM 'false'",
    ];
    const params = [];
    if (audience.location) {
        params.push(property.city.trim().toLowerCase());
        conditions.push(`EXISTS (
      SELECT 1 FROM tenant_profiles tp
      WHERE tp.user_id = u.id
        AND EXISTS (
          SELECT 1 FROM unnest(coalesce(tp.preferred_cities, '{}'::text[])) AS pref_city(value)
          WHERE lower(btrim(pref_city.value)) = $${params.length}
        )
    )`);
    }
    if (audience.propertyType) {
        params.push(property.category.trim().toLowerCase());
        conditions.push(`EXISTS (
      SELECT 1 FROM tenant_profiles tp
      WHERE tp.user_id = u.id
        AND EXISTS (
          SELECT 1 FROM unnest(coalesce(tp.preferred_categories, '{}'::text[])) AS pref_category(value)
          WHERE lower(btrim(pref_category.value)) = $${params.length}
        )
    )`);
    }
    return {
        sql: `SELECT DISTINCT u.id FROM users u WHERE ${conditions.join(' AND ')} ORDER BY u.id`,
        params,
    };
}
//# sourceMappingURL=promotional_campaign_policy.js.map