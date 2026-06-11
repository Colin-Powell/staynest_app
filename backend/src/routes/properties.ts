import { Router, Request, Response, NextFunction } from 'express';
import { query } from '../db.js';
import { getCache, setCache } from '../services/cache.js';
import { requireAuth, authorize } from '../middleware/auth.js';
import jwt from 'jsonwebtoken';
import { env } from '../config.js';

const router = Router();

function normalizePropertyRow(property: Record<string, unknown>): Record<string, unknown> {
  let images = property.images;

  // FIX 1: null guard — pg returns null for empty jsonb, not undefined
  if (images === null) images = undefined;

  if (typeof images === 'string') {
    try {
      images = JSON.parse(images);
    } catch {
      images = [];
    }
  }
  if (!Array.isArray(images) || images.length === 0) {
    if (property.image_url) {
      property.images = [property.image_url];
    } else {
      property.images = [];
    }
  } else {
    property.images = images;
  }

  let amenities = property.amenities;
  if (amenities === null) amenities = undefined;
  if (typeof amenities === 'string') {
    try {
      amenities = JSON.parse(amenities);
    } catch {
      amenities = [];
    }
  }
  if (!Array.isArray(amenities)) {
    property.amenities = [];
  }

  return property;
}

const PROPERTY_SELECT = `p.id,
              p.title,
              p.description,
              p.category,
              p.city,
              p.address,
              p.price,
              p.bedrooms,
              p.bathrooms,
              p.area,
              p.image_url,
              p.images,
              p.amenities,
              p.lat,
              p.lng,
              u.id AS landlord_id,
              u.name AS landlord_name,
              u.email AS landlord_email,
              u.avatar AS landlord_avatar,
              u.verified AS landlord_verified,
              u.business_name AS landlord_business_name,
              u.business_description AS landlord_business_description,
              p.average_rating,
              p.review_count,
              u.created_at AS landlord_member_since`;

router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const category = typeof req.query.category === 'string' ? req.query.category.trim() : undefined;
    const city = typeof req.query.city === 'string' ? req.query.city.trim() : undefined;
    const landlordId = typeof req.query.landlordId === 'string' ? req.query.landlordId.trim() : undefined;
    const lat = typeof req.query.lat === 'string' ? Number(req.query.lat) : undefined;
    const lng = typeof req.query.lng === 'string' ? Number(req.query.lng) : undefined;
    const historyRaw = typeof req.query.history === 'string' ? req.query.history.trim() : undefined;
    const history = historyRaw ? historyRaw.split(',').map((s) => s.trim()).filter(Boolean) : [];

    const cacheKey = `properties.all|category=${category ?? ''}|city=${city ?? ''}|landlordId=${landlordId ?? ''}|lat=${lat ?? ''}|lng=${lng ?? ''}|history=${history.join('|')}`;
    const cached = getCache<any[]>(cacheKey);
    if (cached) {
      return res.json({ data: cached, cached: true });
    }

    const conditions: string[] = [];
    const params: any[] = [];

    if (category != null && category.length > 0) {
      params.push(category);
      conditions.push(`p.category = $${params.length}`);
    }
    if (city != null && city.length > 0) {
      params.push(city);
      conditions.push(`p.city = $${params.length}`);
    }
    if (landlordId != null && landlordId.length > 0) {
      params.push(landlordId);
      conditions.push(`p.landlord_id = $${params.length}`);
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const orderParts: string[] = [];
    if (history.length > 0) {
      params.push(history);
      orderParts.push(`(CASE WHEN p.category = ANY($${params.length}) THEN 0 ELSE 1 END)`);
    }
    if (lat != null && lng != null) {
      params.push(lat, lng);
      orderParts.push(`(CASE WHEN p.lat IS NULL OR p.lng IS NULL THEN 1 ELSE 0 END)`);
      orderParts.push(`(ABS(COALESCE(p.lat,0) - $${params.length - 1}) + ABS(COALESCE(p.lng,0) - $${params.length}))`);
    }

    const orderClause = orderParts.length > 0 ? `${orderParts.join(', ')}, p.created_at DESC` : 'p.created_at DESC';

    const result = await query(
      `SELECT ${PROPERTY_SELECT}
       FROM properties p
       LEFT JOIN users u ON u.id = p.landlord_id
       ${whereClause}
       ORDER BY ${orderClause}`,
      params,
    );

    const rows = result.rows.map((row) => normalizePropertyRow(row as Record<string, unknown>));

    if (conditions.length === 0) {
      setCache(cacheKey, rows, 60_000);
    }

    res.set('Cache-Control', 'public, max-age=60, stale-while-revalidate=30');
    res.json({ data: rows });
  } catch (error) {
    next(error);
  }
});

// Recommendations endpoint
router.get('/recommendations', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const lat = typeof req.query.lat === 'string' ? Number(req.query.lat) : undefined;
    const lng = typeof req.query.lng === 'string' ? Number(req.query.lng) : undefined;
    const historyRaw = typeof req.query.history === 'string' ? req.query.history.trim() : undefined;
    const history = historyRaw ? historyRaw.split(',').map((s) => s.trim()).filter(Boolean) : [];

    let userId: string | undefined;
    const authHeader = typeof req.headers.authorization === 'string' ? req.headers.authorization : undefined;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      try {
        const payload = jwt.verify(token, env.jwtSecret) as any;
        userId = payload?.id;
      } catch (_) {}
    }

    const cacheKey = `properties.recommendations|lat=${lat ?? ''}|lng=${lng ?? ''}|history=${history.join('|')}|user=${userId ?? ''}`;
    const cached = getCache<any[]>(cacheKey);
    if (cached) return res.json({ data: cached, cached: true });

    let profile: any = null;
    if (userId) {
      try {
        const pRes = await query('SELECT * FROM tenant_profiles WHERE user_id = $1 LIMIT 1', [userId]);
        if (typeof pRes.rowCount === 'number' && pRes.rowCount > 0) profile = pRes.rows[0];
      } catch (_) {
        profile = null;
      }
    }

    const params: any[] = [];
    const orderParts: string[] = [];
    const whereParts: string[] = [];

    if (profile && profile.opt_in_personalized) {
      if (profile.budget_min != null) {
        params.push(Number(profile.budget_min));
        whereParts.push(`p.price >= $${params.length}`);
      }
      if (profile.budget_max != null) {
        params.push(Number(profile.budget_max));
        whereParts.push(`p.price <= $${params.length}`);
      }
      if (Array.isArray(profile.preferred_categories) && profile.preferred_categories.length > 0) {
        params.push(profile.preferred_categories);
        orderParts.push(`(CASE WHEN p.category = ANY($${params.length}) THEN 0 ELSE 1 END)`);
      }
      if (Array.isArray(profile.preferred_cities) && profile.preferred_cities.length > 0) {
        params.push(profile.preferred_cities);
        orderParts.push(`(CASE WHEN p.city = ANY($${params.length}) THEN 0 ELSE 1 END)`);
      }
    }

    if (history.length > 0) {
      params.push(history);
      orderParts.push(`(CASE WHEN p.category = ANY($${params.length}) THEN 0 ELSE 1 END)`);
    }
    if (lat != null && lng != null) {
      params.push(lat, lng);
      orderParts.push(`(CASE WHEN p.lat IS NULL OR p.lng IS NULL THEN 1 ELSE 0 END)`);
      orderParts.push(`(ABS(COALESCE(p.lat,0) - $${params.length - 1}) + ABS(COALESCE(p.lng,0) - $${params.length}))`);
    }

    const whereClause = whereParts.length > 0 ? `WHERE ${whereParts.join(' AND ')}` : '';
    const orderClause = orderParts.length > 0 ? `${orderParts.join(', ')}, p.created_at DESC` : 'p.created_at DESC';

    const result = await query(
      `SELECT ${PROPERTY_SELECT}
       FROM properties p
       LEFT JOIN users u ON u.id = p.landlord_id
       ${whereClause}
       ORDER BY ${orderClause}
       LIMIT 12`,
      params,
    );

    const rows = result.rows.map((row) => normalizePropertyRow(row as Record<string, unknown>));
    setCache(cacheKey, rows, 30_000);
    res.json({ data: rows });
  } catch (error) {
    next(error);
  }
});

// Get current user's (landlord) properties
router.get('/me', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      `SELECT ${PROPERTY_SELECT},
              p.created_at,
              p.created_at AS updated_at
       FROM properties p
       LEFT JOIN users u ON u.id = p.landlord_id
       WHERE p.landlord_id = $1
       ORDER BY p.created_at DESC`,
      [req.auth?.id],
    );

    res.json({
      data: result.rows.map((row) => normalizePropertyRow(row as Record<string, unknown>)),
    });
  } catch (error) {
    next(error);
  }
});

// FIX 2: /categories MUST be before /:id — otherwise Express matches
// GET /properties/categories as /:id with id="categories" and returns 404.
router.get('/categories', async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const cacheKey = 'properties.categories';
    const cached = getCache<Record<string, unknown>>(cacheKey);
    if (cached) {
      return res.json({ data: cached, cached: true });
    }

    const result = await query(
      `SELECT category,
              json_agg(json_build_object(
                'id', id,
                'title', title,
                'city', city,
                'price', price,
                'image_url', image_url
              ) ORDER BY created_at DESC) AS items
       FROM properties
       GROUP BY category
       ORDER BY category`,
    );

    const categories = result.rows.reduce<Record<string, unknown>>(
      (acc, row: { category: string; items: unknown }) => {
        acc[row.category] = row.items;
        return acc;
      },
      {},
    );

    setCache(cacheKey, categories, 60_000);
    res.set('Cache-Control', 'public, max-age=60, stale-while-revalidate=30');
    res.json({ data: categories });
  } catch (error) {
    next(error);
  }
});

router.get('/:id/availability-check', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { start, end } = req.query;
    const propertyId = req.params.id;

    if (!start || !end) {
      return res.status(400).json({ error: 'start and end dates are required.' });
    }

    // 1. Check for overlapping confirmed bookings
    const bookingCheck = await query(
      `SELECT id FROM bookings 
       WHERE property_id = $1 
       AND status = 'confirmed' 
       AND (check_in_date, check_out_date) OVERLAPS ($2::date, $3::date)`,
      [propertyId, start, end]
    );

    if (bookingCheck.rowCount! > 0) {
      return res.json({ available: false });
    }

    // 2. Check for manual blocks in property_availability table
    const blockCheck = await query(
      `SELECT id FROM property_availability 
       WHERE property_id = $1 
       AND available = false 
       AND block_date >= $2::date 
       AND block_date < $3::date`,
      [propertyId, start, end]
    );

    res.json({ available: blockCheck.rowCount === 0 });
  } catch (error) {
    next(error);
  }
});

// /:id must be last among GET routes
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      `SELECT ${PROPERTY_SELECT}
       FROM properties p
       LEFT JOIN users u ON u.id = p.landlord_id
       WHERE p.id = $1
       LIMIT 1`,
      [req.params.id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Property not found.' });
    }

    const property = result.rows[0] as Record<string, unknown>;
    const images = property.images;
    const hasImages = Array.isArray(images) && images.length > 0;

    if (!hasImages && property.landlord_id) {
      try {
        const vRes = await query(
          `SELECT property_data
           FROM verifications
           WHERE user_id = $1
             AND property_data->>'title' = $2
           ORDER BY created_at DESC
           LIMIT 1`,
          [property.landlord_id, property.title],
        );
        const propertyData = vRes.rows[0]?.property_data as Record<string, unknown> | undefined;
        const photos = propertyData?.photos;
        if (Array.isArray(photos) && photos.length > 0) {
          property.images = photos;
        }
        if (
          (!property.amenities || (Array.isArray(property.amenities) && property.amenities.length === 0)) &&
          Array.isArray(propertyData?.amenities)
        ) {
          property.amenities = propertyData!.amenities;
        }
      } catch (_) {}
    }

    res.json({ data: normalizePropertyRow(property) });
  } catch (error) {
    next(error);
  }
});

router.post('/:id/availability', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const propertyId = req.params.id;
    const { date, available } = req.body as { date?: string; available?: boolean };

    if (!date || available === undefined) {
      return res.status(400).json({ error: 'date and available status are required.' });
    }

    // Verify ownership
    const propCheck = await query(
      'SELECT id FROM properties WHERE id = $1 AND landlord_id = $2',
      [propertyId, req.auth?.id]
    );

    if (propCheck.rowCount === 0) {
      return res.status(403).json({ error: 'Property not found or access denied.' });
    }

    await query(
      `INSERT INTO property_availability (property_id, block_date, available)
       VALUES ($1, $2::date, $3)
       ON CONFLICT (property_id, block_date) 
       DO UPDATE SET available = EXCLUDED.available, updated_at = now()`,
      [propertyId, date, available]
    );

    res.json({ success: true });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/v1/properties/:id/reviews
 * Fetches all reviews for a specific property including reviewer details
 */
router.get('/:id/reviews', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      `SELECT r.*, 
              u.name as reviewer_name, 
              u.avatar as reviewer_avatar,
              u.role as reviewer_role
       FROM reviews r
       JOIN users u ON u.id = r.reviewer_id
       WHERE r.property_id = $1
       ORDER BY r.created_at DESC`,
      [req.params.id]
    );
    res.json({ data: result.rows });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/v1/properties/reviews
 * Submits a new review. Requires authentication.
 */
router.post('/reviews', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { bookingId, propertyId, rating, comment } = req.body;

    if (!bookingId || !propertyId || !rating) {
      return res.status(400).json({ error: 'Missing required review fields.' });
    }

    // Verify the booking belongs to the user and is 'completed'
    const bookingCheck = await query(
      "SELECT id FROM bookings WHERE id = $1 AND tenant_id = $2 AND status = 'completed'",
      [bookingId, req.auth?.id]
    );

    if (bookingCheck.rowCount === 0) {
      return res.status(403).json({ error: 'You can only review completed bookings that you made.' });
    }

    const result = await query(
      `INSERT INTO reviews (booking_id, property_id, reviewer_id, rating, comment)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [bookingId, propertyId, req.auth?.id, rating, comment]
    );

    res.status(201).json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

router.post('/', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const {
      title,
      description,
      category,
      city,
      address,
      price,
      bedrooms,
      bathrooms,
      area,
      image_url,
      images,
      amenities,
      lat,
      lng,
    } = req.body as Record<string, unknown>;
    if (!title || !description || !category || !city || price == null || bedrooms == null || bathrooms == null || area == null || !image_url) {
      return res.status(400).json({ error: 'All property fields are required.' });
    }

    const imageList = Array.isArray(images) && images.length > 0
      ? images
      : [image_url];
    const amenityList = Array.isArray(amenities) ? amenities : [];

    const result = await query(
      `INSERT INTO properties (title, description, category, city, address, price, bedrooms, bathrooms, area, image_url, images, amenities, lat, lng, landlord_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, $12::jsonb, $13, $14, $15)
       RETURNING id, title, description, category, city, address, price, bedrooms, bathrooms, area, image_url, images, amenities, lat, lng`,
      [
        title,
        description,
        category,
        city,
        typeof address === 'string' ? address : null,
        Number(price),
        Number(bedrooms),
        Number(bathrooms),
        Number(area),
        image_url,
        JSON.stringify(imageList),
        JSON.stringify(amenityList),
        lat != null ? Number(lat) : null,
        lng != null ? Number(lng) : null,
        req.auth?.id,
      ],
    );

    res.status(201).json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

export default router;