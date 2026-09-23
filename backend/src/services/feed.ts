import { query } from '../db.js';

export interface FeedContext {
  lat?: number;
  lng?: number;
  radiusKm?: number;
  campusId?: string;
  locationId?: string;
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

export class FeedService {
  public static async generateFeed(context: FeedContext, limit: number = 20): Promise<FeedSection[]> {
    const sections: FeedSection[] = [];

    // Normalize items func (assuming normalizePropertyRow will be used in route or here)
    // For simplicity, we just return the raw rows and let the route normalize.

    // 1. Nearby section
    if (context.lat && context.lng) {
      const nearbyQuery = `
        SELECT p.*
        FROM properties p
        WHERE COALESCE(p.status, 'pending_review') = 'approved'
          AND p.lat IS NOT NULL AND p.lng IS NOT NULL
        ORDER BY (
          6371 * acos(cos(radians($1)) * cos(radians(p.lat)) *
          cos(radians(p.lng) - radians($2)) + sin(radians($1)) *
          sin(radians(p.lat)))
        ) ASC
        LIMIT $3
      `;
      const nearbyRes = await query(nearbyQuery, [context.lat, context.lng, limit]);
      if (nearbyRes.rows.length > 0) {
        sections.push({
          id: 'nearby_places',
          type: 'property_carousel',
          title: 'Nearby Places',
          subtitle: 'Properties near you',
          algorithm: 'nearby_v1',
          items: nearbyRes.rows,
          hasMore: false,
        });
      }
    }

    // 2. New listings
    const freshQuery = `
      SELECT p.*
      FROM properties p
      WHERE COALESCE(p.status, 'pending_review') = 'approved'
      ORDER BY COALESCE(p.updated_at, p.created_at) DESC
      LIMIT $1
    `;
    const freshRes = await query(freshQuery, [limit]);
    if (freshRes.rows.length > 0) {
      sections.push({
        id: 'new_listings',
        type: 'property_carousel',
        title: 'New on StayNest',
        subtitle: 'Recently added properties',
        algorithm: 'fresh_v1',
        items: freshRes.rows,
        hasMore: false,
      });
    }

    // 3. Trending (highly rated)
    const trendingQuery = `
      SELECT p.*
      FROM properties p
      WHERE COALESCE(p.status, 'pending_review') = 'approved'
        AND p.average_rating >= 4.0
      ORDER BY p.average_rating DESC, p.review_count DESC
      LIMIT $1
    `;
    const trendingRes = await query(trendingQuery, [limit]);
    if (trendingRes.rows.length > 0) {
      sections.push({
        id: 'trending_now',
        type: 'property_grid',
        title: 'Trending Now',
        subtitle: 'Highly rated properties',
        algorithm: 'trending_v1',
        items: trendingRes.rows,
        hasMore: false,
      });
    }

    // 4. Cold-start fallback: if no sections generated (no coordinates, no
    //    highly-rated listings), show a general "Discover" section so the
    //    feed is never blank.
    if (sections.length === 0) {
      const fallbackQuery = `
        SELECT p.*
        FROM properties p
        WHERE COALESCE(p.status, 'pending_review') = 'approved'
        ORDER BY COALESCE(p.updated_at, p.created_at) DESC
        LIMIT $1
      `;
      const fallbackRes = await query(fallbackQuery, [limit]);
      if (fallbackRes.rows.length > 0) {
        sections.push({
          id: 'discover',
          type: 'property_carousel',
          title: 'Discover Properties',
          subtitle: 'Find your next stay',
          algorithm: 'fallback_v1',
          items: fallbackRes.rows,
          hasMore: false,
        });
      }
    }

    return sections;
  }
}
