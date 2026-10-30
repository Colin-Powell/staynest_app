import { query } from '../db.js';
import {
  buildTrendingPropertiesQuery,
  NEW_LISTING_WINDOW_DAYS,
  TRENDING_MIN_UNIQUE_TENANTS,
  TRENDING_WINDOW_DAYS,
} from './discovery_rules.js';
import { publicPropertyCategorySql } from './property_category.js';
import {
  MAX_HOME_FEED_PROPERTIES_PER_LOCATION,
  MAX_HOME_FEED_LOCATION_SECTIONS,
  publicPropertyLocationSql,
} from './feed_location.js';

export interface FeedContext {
  lat?: number;
  lng?: number;
  radiusKm?: number;
  campusId?: string;
  locationId?: string;
  category?: string;
  userId?: string;
}

export interface FeedSection {
  id: string;
  type: string;
  title: string;
  subtitle?: string;
  algorithm: string;
  items: any[];
  nextCursor?: string | null;
  hasMore: boolean;
}

type ResolvedContext = FeedContext & {
  anchorLat?: number;
  anchorLng?: number;
  locationName?: string;
  locationTown?: string;
  locationNeighborhood?: string;
};

const APPROVED = "COALESCE(p.status, 'pending_review') = 'approved'";

function distanceSql(latParam: number, lngParam: number): string {
  return `(6371 * 2 * ASIN(SQRT(
    POWER(SIN(RADIANS(p.lat - $${latParam}) / 2), 2) +
    COS(RADIANS($${latParam})) * COS(RADIANS(p.lat)) *
    POWER(SIN(RADIANS(p.lng - $${lngParam}) / 2), 2)
  )))`;
}

async function resolveContext(context: FeedContext): Promise<ResolvedContext> {
  let anchorLat = context.lat;
  let anchorLng = context.lng;
  let locationName: string | undefined;
  let locationTown: string | undefined;
  let locationNeighborhood: string | undefined;
  const locationId = context.locationId || context.campusId;

  if (locationId) {
    const result = await query(
      `SELECT name, town, neighborhood, latitude, longitude
         FROM locations WHERE id = $1 LIMIT 1`,
      [locationId],
    );
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

function filtersFor(
  context: ResolvedContext,
  params: any[],
  excluded: string[],
  includeCampus = true,
): string[] {
  const filters = [APPROVED];

  if (context.category && context.category.toLowerCase() !== 'all') {
    params.push(context.category);
    const categoryParam = `$${params.length}`;
    const propertyCategory = publicPropertyCategorySql();
    filters.push(`(
      LOWER(${propertyCategory}) = LOWER(${categoryParam})
      OR LOWER(${propertyCategory}) = LOWER(REGEXP_REPLACE(${categoryParam}, 's$', ''))
      OR REGEXP_REPLACE(LOWER(${propertyCategory}), '[ _-]+', '_', 'g') =
         REGEXP_REPLACE(LOWER(${categoryParam}), '[ _-]+', '_', 'g')
      OR REGEXP_REPLACE(LOWER(${propertyCategory}), '[ _-]+', '_', 'g') =
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
    ].filter((value): value is string => Boolean(value));
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

function section(
  id: string,
  type: string,
  title: string,
  subtitle: string,
  algorithm: string,
  items: any[],
): FeedSection | null {
  if (items.length === 0) return null;
  return { id, type, title, subtitle, algorithm, items, hasMore: false };
}

export class FeedService {
  public static async generateFeed(
    context: FeedContext,
    requestedLimit: number = 20,
  ): Promise<FeedSection[]> {
    const limit = Math.min(Math.max(requestedLimit, 1), 50);
    const resolved = await resolveContext(context);
    const radiusKm = Math.min(Math.max(resolved.radiusKm ?? 5, 0.5), 50);
    const sections: FeedSection[] = [];

    const addSection = (candidate: FeedSection | null) => {
      if (!candidate) return;
      sections.push(candidate);
    };

    if (resolved.anchorLat != null && resolved.anchorLng != null) {
      const params: any[] = [];
      const filters = filtersFor(resolved, params, []);
      params.push(resolved.anchorLat, resolved.anchorLng);
      const distance = distanceSql(params.length - 1, params.length);
      params.push(radiusKm, limit);
      filters.push(`${distance} <= $${params.length - 1}`);
      const result = await query(
        `SELECT p.*, u.role AS landlord_role FROM properties p
         LEFT JOIN users u ON u.id = p.landlord_id
         WHERE ${filters.join(' AND ')}
         ORDER BY ${distance} ASC, p.created_at DESC, p.id
         LIMIT $${params.length}`,
        params,
      );
      let nearbyItems = result.rows;
      let hasNearbyItems = nearbyItems.length > 0;
      if (!hasNearbyItems) {
        const nearestParams: any[] = [];
        const nearestFilters = filtersFor(resolved, nearestParams, []);
        nearestParams.push(resolved.anchorLat, resolved.anchorLng);
        const nearestDistance = distanceSql(
          nearestParams.length - 1,
          nearestParams.length,
        );
        nearestParams.push(limit);
        const nearestResult = await query(
          `SELECT p.*, u.role AS landlord_role FROM properties p
           LEFT JOIN users u ON u.id = p.landlord_id
           WHERE ${nearestFilters.join(' AND ')}
           ORDER BY ${nearestDistance} ASC, p.created_at DESC, p.id
           LIMIT $${nearestParams.length}`,
          nearestParams,
        );
        nearbyItems = nearestResult.rows;
      }
      hasNearbyItems = result.rows.length > 0;
      addSection(section(
        'nearby_places',
        'property_carousel',
        hasNearbyItems
          ? resolved.category && resolved.category !== 'All'
              ? `${resolved.category} Near You`
              : 'Nearby Places'
          : resolved.category && resolved.category !== 'All'
              ? `Closest ${resolved.category}`
              : 'Closest Places',
        hasNearbyItems
          ? `Listings within ${radiusKm} km`
          : `No listings within ${radiusKm} km; showing the closest listings`,
        'nearby_radius_v2',
        nearbyItems,
      ));
    }

    {
      const params: any[] = [];
      const filters = filtersFor(resolved, params, []);
      params.push(limit);
      const result = await query(
        `SELECT p.*, u.role AS landlord_role FROM properties p
         LEFT JOIN users u ON u.id = p.landlord_id
         WHERE ${filters.join(' AND ')}
           AND p.published_at IS NOT NULL
           AND p.published_at >= NOW() - INTERVAL '${NEW_LISTING_WINDOW_DAYS} days'
         ORDER BY p.published_at DESC, p.id
         LIMIT $${params.length}`,
        params,
      );
      addSection(section(
        'new_listings',
        'property_carousel',
        'New on StayNest',
        `Approved in the last ${NEW_LISTING_WINDOW_DAYS} days`,
        'approved_published_at_v1',
        result.rows,
      ));
    }

    {
      const params: any[] = [];
      const filters = filtersFor(resolved, params, []);
      params.push(limit);
      const result = await query(
        buildTrendingPropertiesQuery(filters.join(' AND '), params.length),
        params,
      );
      addSection(section(
        'trending_now',
        'property_grid',
        resolved.anchorLat != null ? 'Trending Near You' : 'Trending Now',
        `At least ${TRENDING_MIN_UNIQUE_TENANTS} tenants engaged in the last ${TRENDING_WINDOW_DAYS} days`,
        'deduplicated_tenant_engagement_per_exposure_v1',
        result.rows,
      ));
    }

    {
      const locationContext = {
        ...resolved,
        campusId: undefined,
        locationId: undefined,
      };
      const params: any[] = [];
      const filters = filtersFor(locationContext, params, [], false);
      const location = publicPropertyLocationSql();
      params.push(
        MAX_HOME_FEED_LOCATION_SECTIONS,
        MAX_HOME_FEED_PROPERTIES_PER_LOCATION,
      );
      const result = await query(
        `WITH eligible AS (
           SELECT p.*, ${location} AS feed_location, u.role AS landlord_role
           FROM properties p
           LEFT JOIN users u ON u.id = p.landlord_id
           WHERE ${filters.join(' AND ')}
         ), locations AS (
           SELECT LOWER(BTRIM(feed_location)) AS location_key,
                  MIN(BTRIM(feed_location)) AS location_name,
                  COUNT(*) AS property_count
           FROM eligible
           WHERE NULLIF(BTRIM(feed_location), '') IS NOT NULL
           GROUP BY LOWER(BTRIM(feed_location))
           ORDER BY property_count DESC, location_name ASC
           LIMIT $${params.length - 1}
         ), ranked AS (
           SELECT eligible.*, locations.location_name,
                  ROW_NUMBER() OVER (
                    PARTITION BY LOWER(BTRIM(eligible.feed_location))
                    ORDER BY eligible.published_at DESC NULLS LAST,
                             eligible.created_at DESC, eligible.id
                  ) AS location_rank
           FROM eligible
           JOIN locations
             ON LOWER(BTRIM(eligible.feed_location)) = locations.location_key
         )
         SELECT * FROM ranked
         WHERE location_rank <= $${params.length}
         ORDER BY location_name ASC, location_rank ASC`,
        params,
      );

      const locationSections = new Map<
        string,
        { locationName: string; items: any[] }
      >();
      for (const row of result.rows) {
        const locationName = String(row.location_name ?? '').trim();
        if (!locationName) continue;

        const locationKey = locationName.toLowerCase();
        let locationSection = locationSections.get(locationKey);
        if (!locationSection) {
          locationSection = { locationName, items: [] };
          locationSections.set(locationKey, locationSection);
        }

        const item = { ...row };
        delete item.feed_location;
        delete item.location_name;
        delete item.location_rank;
        locationSection.items.push(item);
      }

      for (const { locationName, items } of locationSections.values()) {
        const locationId = locationName
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '_')
          .replace(/^_+|_+$/g, '');
        addSection(section(
          `properties_in_${locationId}`,
          'property_carousel',
          `Properties in ${locationName}`,
          `Available stays in ${locationName}`,
          'approved_properties_by_location_v1',
          items,
        ));
      }
    }

    if (sections.length === 0) {
      const params: any[] = [];
      let filters = filtersFor(resolved, params, []);
      params.push(limit);
      let result = await query(
        `SELECT p.*, u.role AS landlord_role FROM properties p
         LEFT JOIN users u ON u.id = p.landlord_id
         WHERE ${filters.join(' AND ')}
         ORDER BY p.created_at DESC, p.id
         LIMIT $${params.length}`,
        params,
      );

      // A campus is a preference, not a hard dependency. If its inventory is
      // empty, retry the same category globally before returning no feed.
      if (result.rows.length === 0 && resolved.campusId) {
        const fallbackParams: any[] = [];
        filters = filtersFor(resolved, fallbackParams, [], false);
        fallbackParams.push(limit);
        result = await query(
          `SELECT p.*, u.role AS landlord_role FROM properties p
           LEFT JOIN users u ON u.id = p.landlord_id
           WHERE ${filters.join(' AND ')}
           ORDER BY p.created_at DESC, p.id
           LIMIT $${fallbackParams.length}`,
          fallbackParams,
        );
      }
      addSection(section(
        'discover',
        'property_carousel',
        resolved.category && resolved.category !== 'All'
            ? `Discover ${resolved.category}`
            : 'Discover Properties',
        'Find your next stay',
        'fallback_created_at_v2',
        result.rows,
      ));
    }

    return sections;
  }
}
