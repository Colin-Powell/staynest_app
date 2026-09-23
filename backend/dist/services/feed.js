import { query } from '../db.js';
const APPROVED = "COALESCE(p.status, 'pending_review') = 'approved'";
function distanceSql(latParam, lngParam) {
    return `(6371 * 2 * ASIN(SQRT(
    POWER(SIN(RADIANS(p.lat - $${latParam}) / 2), 2) +
    COS(RADIANS($${latParam})) * COS(RADIANS(p.lat)) *
    POWER(SIN(RADIANS(p.lng - $${lngParam}) / 2), 2)
  )))`;
}
async function resolveContext(context) {
    let anchorLat = context.lat;
    let anchorLng = context.lng;
    let locationName;
    let locationTown;
    let locationNeighborhood;
    const locationId = context.locationId || context.campusId;
    if (locationId) {
        const result = await query(`SELECT name, town, neighborhood, latitude, longitude
         FROM locations WHERE id = $1 LIMIT 1`, [locationId]);
        const row = result.rows[0];
        locationName = row?.name?.toString();
        locationTown = row?.town?.toString();
        locationNeighborhood = row?.neighborhood?.toString();
        const parsedLat = row?.latitude == null ? undefined : Number(row.latitude);
        const parsedLng = row?.longitude == null ? undefined : Number(row.longitude);
        if ((anchorLat == null || anchorLng == null) &&
            Number.isFinite(parsedLat) && Number.isFinite(parsedLng)) {
            anchorLat = parsedLat;
            anchorLng = parsedLng;
        }
    }
    return {
        ...context,
        anchorLat,
        anchorLng,
        locationName,
        locationTown,
        locationNeighborhood,
    };
}
function filtersFor(context, params, excluded, includeCampus = true) {
    const filters = [APPROVED];
    if (context.category && context.category.toLowerCase() !== 'all') {
        params.push(context.category);
        const categoryParam = `$${params.length}`;
        filters.push(`(
      LOWER(p.category) = LOWER(${categoryParam})
      OR LOWER(p.category) = LOWER(REGEXP_REPLACE(${categoryParam}, 's$', ''))
      OR REGEXP_REPLACE(LOWER(p.category), '[ _-]+', '_', 'g') =
         REGEXP_REPLACE(LOWER(${categoryParam}), '[ _-]+', '_', 'g')
      OR REGEXP_REPLACE(LOWER(p.category), '[ _-]+', '_', 'g') =
         REGEXP_REPLACE(LOWER(${categoryParam}), '[ _-]+', '_', 'g') || '_room'
      OR EXISTS (SELECT 1 FROM property_types pt
        WHERE pt.id = p.property_type_id
          AND REGEXP_REPLACE(LOWER(pt.label), '[ _-]+', '_', 'g') =
              REGEXP_REPLACE(LOWER(${categoryParam}), '[ _-]+', '_', 'g'))
      OR EXISTS (SELECT 1 FROM room_types rt
        WHERE rt.id = p.room_type_id
          AND REGEXP_REPLACE(LOWER(rt.label), '[ _-]+', '_', 'g') =
              REGEXP_REPLACE(LOWER(${categoryParam}), '[ _-]+', '_', 'g'))
    )`);
    }
    if (includeCampus && context.campusId) {
        params.push(context.campusId);
        filters.push(`p.campus_id = $${params.length}`);
    }
    if (context.locationId && !context.campusId) {
        const locationParts = [
            context.locationNeighborhood,
            context.locationName,
            context.locationTown,
        ].filter((value) => Boolean(value));
        if (locationParts.length > 0) {
            params.push(context.locationId);
            const locationIdParam = `$${params.length}`;
            params.push(locationParts);
            filters.push(`(
        p.campus_id::text = ${locationIdParam}
        OR LOWER(COALESCE(p.neighborhood, '')) = ANY(
          SELECT LOWER(value) FROM unnest($${params.length}::text[]) AS value)
        OR LOWER(COALESCE(p.town, '')) = ANY(
          SELECT LOWER(value) FROM unnest($${params.length}::text[]) AS value)
        OR LOWER(COALESCE(p.city, '')) = ANY(
          SELECT LOWER(value) FROM unnest($${params.length}::text[]) AS value)
      )`);
        }
    }
    if (excluded.length > 0) {
        params.push(excluded);
        filters.push(`p.id <> ALL($${params.length}::uuid[])`);
    }
    return filters;
}
function section(id, type, title, subtitle, algorithm, items) {
    if (items.length === 0)
        return null;
    return { id, type, title, subtitle, algorithm, items, hasMore: false };
}
export class FeedService {
    static async generateFeed(context, requestedLimit = 20) {
        const limit = Math.min(Math.max(requestedLimit, 1), 50);
        const resolved = await resolveContext(context);
        const radiusKm = Math.min(Math.max(resolved.radiusKm ?? 5, 0.5), 50);
        const sections = [];
        const excluded = new Set();
        const addSection = (candidate) => {
            if (!candidate)
                return;
            candidate.items.forEach((item) => excluded.add(String(item.id)));
            sections.push(candidate);
        };
        if (resolved.anchorLat != null && resolved.anchorLng != null) {
            const params = [];
            const filters = filtersFor(resolved, params, []);
            params.push(resolved.anchorLat, resolved.anchorLng);
            const distance = distanceSql(params.length - 1, params.length);
            params.push(radiusKm, limit);
            filters.push(`${distance} <= $${params.length - 1}`);
            const result = await query(`SELECT p.* FROM properties p
         WHERE ${filters.join(' AND ')}
         ORDER BY ${distance} ASC, p.created_at DESC, p.id
         LIMIT $${params.length}`, params);
            addSection(section('nearby_places', 'property_carousel', resolved.category && resolved.category !== 'All'
                ? `${resolved.category} Near You`
                : 'Nearby Places', `Available within ${radiusKm} km`, 'nearby_radius_v2', result.rows));
        }
        {
            const params = [];
            const filters = filtersFor(resolved, params, [...excluded]);
            params.push(limit);
            const result = await query(`SELECT p.* FROM properties p
         WHERE ${filters.join(' AND ')}
         ORDER BY p.created_at DESC, p.id
         LIMIT $${params.length}`, params);
            addSection(section('new_listings', 'property_carousel', 'New on StayNest', 'Recently added properties', 'fresh_created_at_v2', result.rows));
        }
        {
            const params = [];
            const filters = filtersFor(resolved, params, [...excluded]);
            params.push(limit);
            const result = await query(`SELECT p.*, COALESCE(pa.velocity_score, 0) AS velocity_score,
                COALESCE(pa.engagement_score, 0) AS engagement_score
           FROM properties p
           LEFT JOIN property_analytics pa ON pa.property_id = p.id
          WHERE ${filters.join(' AND ')}
          ORDER BY COALESCE(pa.velocity_score, 0) DESC,
                   COALESCE(pa.engagement_score, 0) DESC,
                   COALESCE(p.average_rating, 0) DESC,
                   p.created_at DESC, p.id
          LIMIT $${params.length}`, params);
            addSection(section('trending_now', 'property_grid', resolved.anchorLat != null ? 'Trending Near You' : 'Trending Now', 'Popular properties with recent engagement', 'trending_velocity_v2', result.rows));
        }
        if (sections.length === 0) {
            const params = [];
            let filters = filtersFor(resolved, params, []);
            params.push(limit);
            let result = await query(`SELECT p.* FROM properties p
         WHERE ${filters.join(' AND ')}
         ORDER BY p.created_at DESC, p.id
         LIMIT $${params.length}`, params);
            // A campus is a preference, not a hard dependency. If its inventory is
            // empty, retry the same category globally before returning no feed.
            if (result.rows.length === 0 && resolved.campusId) {
                const fallbackParams = [];
                filters = filtersFor(resolved, fallbackParams, [], false);
                fallbackParams.push(limit);
                result = await query(`SELECT p.* FROM properties p
           WHERE ${filters.join(' AND ')}
           ORDER BY p.created_at DESC, p.id
           LIMIT $${fallbackParams.length}`, fallbackParams);
            }
            addSection(section('discover', 'property_carousel', resolved.category && resolved.category !== 'All'
                ? `Discover ${resolved.category}`
                : 'Discover Properties', 'Find your next stay', 'fallback_created_at_v2', result.rows));
        }
        return sections;
    }
}
//# sourceMappingURL=feed.js.map