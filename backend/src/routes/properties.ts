import { Router, Request, Response, NextFunction } from 'express';
import { query } from '../db.js';
import { getCache, setCache, clearCachePattern } from '../services/cache.js';
import { requireAuth, authorize } from '../middleware/auth.js';
import jwt from 'jsonwebtoken';
import { env } from '../config.js';
import { sendPushToTopic } from '../services/firebase.js';

const router = Router();

function normalizePropertyRow(property: Record<string, unknown>): Record<string, unknown> {
  let images = property.images;

  // Ensure status is always defined for the frontend.
  if (!property.status) {
    property.status = 'available';
  }

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
              p.status,
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
      orderParts.push(`(
        6371 * 2 * ASIN(SQRT(
          POWER(SIN(RADIANS(p.lat - $${params.length - 1}) / 2), 2) +
          COS(RADIANS($${params.length - 1})) * COS(RADIANS(p.lat)) *
          POWER(SIN(RADIANS(p.lng - $${params.length}) / 2), 2)
        ))
      )`);
    }

    const orderClause = orderParts.length > 0 ? `${orderParts.join(', ')}, p.created_at DESC` : 'p.created_at DESC';

    const result = await query(
      `SELECT ${PROPERTY_SELECT}
       FROM properties p
       LEFT JOIN users u ON u.id = p.landlord_id
       ${whereClause}
       ORDER BY ${orderClause}
       LIMIT 50`,
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
      [propertyId, start, end],
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
      [propertyId, start, end],
    );

    res.json({ available: blockCheck.rowCount === 0 });
  } catch (error) {
    next(error);
  }
});

// Nearby properties based on lat, lng, and radius (default 5km)
router.get('/nearby', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const lat = typeof req.query.lat === 'string' ? Number(req.query.lat) : undefined;
    const lng = typeof req.query.lng === 'string' ? Number(req.query.lng) : undefined;
    const radius = typeof req.query.radius === 'string' ? Number(req.query.radius) : 5;

    if (lat === undefined || lng === undefined || isNaN(lat) || isNaN(lng)) {
      return res.status(400).json({ error: 'lat and lng are required and must be valid numbers.' });
    }

    const result = await query(
      `SELECT ${PROPERTY_SELECT},
              (6371 * acos(cos(radians($1)) * cos(radians(p.lat)) * cos(radians(p.lng) - radians($2)) + sin(radians($1)) * sin(radians(p.lat)))) AS distance
       FROM properties p
       LEFT JOIN users u ON u.id = p.landlord_id
       WHERE p.lat IS NOT NULL AND p.lng IS NOT NULL
         AND (6371 * acos(cos(radians($1)) * cos(radians(p.lat)) * cos(radians(p.lng) - radians($2)) + sin(radians($1)) * sin(radians(p.lat)))) <= $3
       ORDER BY distance ASC
       LIMIT 50`,
      [lat, lng, radius]
    );

    const rows = result.rows.map((row) => normalizePropertyRow(row as Record<string, unknown>));
    res.json({ data: rows });
  } catch (error) {
    next(error);
  }
});

// /:id must be last among GET routes
router.get('/:id([0-9a-fA-F-]{36})', async (req: Request, res: Response, next: NextFunction) => {
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

router.patch('/:id/status', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { status } = req.body;
    const propertyId = req.params.id;
    const userId = req.auth?.id;

    console.log(`[PropertyStatusUpdate] Request to update property ${propertyId} to status "${status}" by user ${userId}`);

    const allowedStatuses = ['available', 'pending_booking', 'fully_booked', 'rented', 'maintenance'];
    if (typeof status !== 'string' || !allowedStatuses.includes(status)) {
      return res.status(400).json({ error: `Status must be one of: ${allowedStatuses.join(', ')}.` });
    }

    console.log(`[PropertyStatusUpdate] Query Params: status=${status}, propertyId=${propertyId}, userId=${userId}`);

    const result = await query(
      'UPDATE properties SET status = $1 WHERE id = $2 AND landlord_id = $3 RETURNING *',
      [status, propertyId, userId],
    );

    console.log(`[PropertyStatusUpdate] Query result rowCount: ${result.rowCount}`);

    if (result.rowCount === 0) {
      console.warn(`[PropertyStatusUpdate] No rows updated. Either property ${propertyId} doesn't exist or user ${userId} is not the landlord.`);
      return res.status(404).json({ error: 'Property not found or access denied.' });
    }

    console.log(`[PropertyStatusUpdate] Successfully updated property ${propertyId}`);
    res.json({ data: normalizePropertyRow(result.rows[0] as Record<string, unknown>) });
  } catch (error) {
    const propertyId = req.params.id;
    console.error(`[PropertyStatusUpdate] Database Error updating property ${propertyId}:`, error);
    next(error);
  }
});

router.delete('/:id', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      'DELETE FROM properties WHERE id = $1 AND landlord_id = $2 RETURNING id',
      [req.params.id, req.auth?.id],
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Property not found or access denied.' });
    }
    clearCachePattern('properties.');
    res.json({ data: { id: result.rows[0].id, deleted: true } });
  } catch (error) {
    next(error);
  }
});

router.get('/:id/availability', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const property = await query(
      'SELECT id FROM properties WHERE id = $1 AND landlord_id = $2 LIMIT 1',
      [req.params.id, req.auth?.id],
    );
    if (property.rowCount === 0) {
      return res.status(404).json({ error: 'Property not found or access denied.' });
    }
    const result = await query(
      `SELECT EXTRACT(DAY FROM block_date)::integer AS day
       FROM property_availability
       WHERE property_id = $1 AND available = false
       AND block_date >= CURRENT_DATE AND block_date < CURRENT_DATE + INTERVAL '14 days'
       ORDER BY block_date`,
      [req.params.id],
    );
    res.json({ blocked_days: result.rows.map((row) => row.day) });
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
      [propertyId, req.auth?.id],
    );

    if (propCheck.rowCount === 0) {
      return res.status(403).json({ error: 'Property not found or access denied.' });
    }

    await query(
      `INSERT INTO property_availability (property_id, block_date, available)
       VALUES ($1, $2::date, $3)
       ON CONFLICT (property_id, block_date) 
       DO UPDATE SET available = EXCLUDED.available, updated_at = now()`,
      [propertyId, date, available],
    );

    res.json({ success: true });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/v1/properties/:id/review-eligibility
 * Checks if the authenticated user can review a specific property.
 */
router.get('/:id/review-eligibility', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const propertyId = req.params.id;
    const userId = req.auth?.id;

    // Find the latest completed booking for this user and property
    const bookingRes = await query(
      `SELECT id FROM bookings 
       WHERE property_id = $1 AND tenant_id = $2 AND status = 'completed'
       ORDER BY check_out_date DESC LIMIT 1`,
      [propertyId, userId],
    );

    if (bookingRes.rowCount === 0) {
      return res.json({ canReview: false, reason: 'No completed booking found' });
    }

    const bookingId = bookingRes.rows[0].id;

    // Check if user has already reviewed this specific booking
    const reviewRes = await query(
      "SELECT id FROM reviews WHERE booking_id = $1",
      [bookingId],
    );

    const reviewExists = (reviewRes.rowCount ?? 0) > 0;
    res.json({ 
      canReview: !reviewExists, 
      bookingId,
      reviewExists 
    });
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
      [req.params.id],
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
    const { bookingId, propertyId, rating, comment } = req.body as { 
      bookingId: string; 
      propertyId: string; 
      rating: number; 
      comment?: string 
    };

    if (!bookingId || !propertyId || !rating) {
      return res.status(400).json({ error: 'Missing required review fields.' });
    }

    // Verify the booking exists, belongs to the user, the property, and is 'completed'
    const bookingCheck = await query(
      "SELECT id FROM bookings WHERE id = $1 AND tenant_id = $2 AND property_id = $3 AND status = 'completed' LIMIT 1",
      [bookingId, req.auth?.id, propertyId],
    );

    if (bookingCheck.rowCount === 0) {
      return res.status(403).json({ success: false, message: 'You are not eligible to review this property.' });
    }

    // Extra safety: Check if a review already exists for this booking
    const existingReview = await query("SELECT id FROM reviews WHERE booking_id = $1", [bookingId]);
    if ((existingReview.rowCount ?? 0) > 0) {
      return res.status(400).json({ success: false, message: 'You have already reviewed this stay.' });
    }

    const result = await query(
      `INSERT INTO reviews (booking_id, property_id, reviewer_id, rating, comment)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [bookingId, propertyId, req.auth?.id, rating, comment],
    );

    res.status(201).json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/v1/reviews/:id/report
 * Submits a report for an inappropriate review. Requires authentication.
 */
router.post('/reviews/:id/report', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const reviewId = req.params.id;
    const { reason } = req.body as { reason: string };

    if (!reason) {
      return res.status(400).json({ error: 'Report reason is required.' });
    }

    // Ensure the review exists
    const reviewCheck = await query('SELECT id FROM reviews WHERE id = $1', [reviewId]);
    if (reviewCheck.rowCount === 0) {
      return res.status(404).json({ error: 'Review not found.' });
    }

    await query(
      `INSERT INTO review_reports (review_id, reporter_id, reason, status)
       VALUES ($1, $2, $3, 'pending')`,
      [reviewId, req.auth!.id, reason],
    );

    res.status(201).json({ message: 'Review reported successfully.' });
  } catch (error) {
    next(error);
  }
});

function createPropertyInsertArgs(body: Record<string, unknown>) {
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
  } = body;

  const imageList = Array.isArray(images) && images.length > 0 ? images : [image_url];
  const amenityList = Array.isArray(amenities) ? amenities : [];

  return [
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
    (body as any).__userId,
  ];
}

function validatePropertyCreateBody(body: Record<string, unknown>) {
  const {
    title,
    description,
    category,
    city,
    price,
    bedrooms,
    bathrooms,
    area,
    image_url,
  } = body;

  const missing: string[] = [];
  if (!title) missing.push('title');
  if (!description) missing.push('description');
  if (!category) missing.push('category');
  if (!city) missing.push('city');
  if (price == null) missing.push('price');
  if (bedrooms == null) missing.push('bedrooms');
  if (bathrooms == null) missing.push('bathrooms');
  if (area == null) missing.push('area');
  if (!image_url) missing.push('image_url');

  return missing;
}

async function handleCreateProperty(req: Request, res: Response, next: NextFunction, logRouteName: string) {
  const logPrefix = `[${logRouteName}]`;
  const userId = req.auth?.id;
  const body = req.body as Record<string, unknown>;
  const receivedKeys = Object.keys(body ?? {});

  // IMPORTANT: don’t log huge fields (like base64/images). This endpoint expects URLs/arrays.
  console.log(`${logPrefix} start userId=${userId} receivedKeys=${receivedKeys.join(',')}`);

  try {
    const missing = validatePropertyCreateBody(body);
    if (missing.length > 0) {
      console.warn(`${logPrefix} missingFields userId=${userId} missing=${missing.join(',')}`);
      return res.status(400).json({ error: 'All property fields are required.', missing });
    }

    const imageList = Array.isArray(body.images) && body.images.length > 0 ? body.images : [body.image_url];
    const amenityList = Array.isArray(body.amenities) ? body.amenities : [];

    console.log(
      `${logPrefix} image_urlType=${typeof body.image_url} imagesIsArray=${Array.isArray(body.images)} imageCount=${Array.isArray(imageList) ? imageList.length : 0} amenitiesIsArray=${Array.isArray(body.amenities)} amenityCount=${Array.isArray(amenityList) ? amenityList.length : 0}`,
    );

    if (Array.isArray(body.images) && body.images.length > 0) {
      const first = body.images[0];
      console.log(`${logPrefix} firstImagePreview=${typeof first === 'string' ? first.slice(0, 80) : typeof first}`);
    }

    const insertArgs = createPropertyInsertArgs({ ...body, __userId: userId });

    console.log(
      `${logPrefix} inserting userId=${userId} lat=${body.lat ?? null} lng=${body.lng ?? null} price=${Number(body.price)} area=${Number(body.area)}`,
    );

    const result = await query(
      `INSERT INTO properties (title, description, category, city, address, price, bedrooms, bathrooms, area, image_url, images, amenities, lat, lng, landlord_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, $12::jsonb, $13, $14, $15)
       RETURNING id, title, description, category, city, address, price, bedrooms, bathrooms, area, image_url, images, amenities, lat, lng`,
      insertArgs,
    );

    console.log(`${logPrefix} success userId=${userId} propertyId=${result.rows[0]?.id}`);
    
    // Broadcast push notification asynchronously
    sendPushToTopic(
      'new_listings', 
      'New Property Listed!', 
      `${result.rows[0]?.title} is now available in ${result.rows[0]?.city}. Check it out!`,
      { propertyId: result.rows[0]?.id }
    ).catch(e => console.error('Failed to broadcast new listing push', e));

    // Clear the properties cache so tenants see the new listing immediately
    clearCachePattern('properties.all');

    res.status(201).json({ data: result.rows[0] });
  } catch (error) {
    console.error(`${logPrefix} failed userId=${userId} error=`, error);
    next(error);
  }
}

// Existing route (kept)
router.post('/', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  await handleCreateProperty(req, res, next, 'PropertyCreate');
});

// Route required by the current Flutter listing flow
router.post('/from-listing', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  await handleCreateProperty(req, res, next, 'PropertyCreateFromListing');
});

router.put('/:id([0-9a-fA-F-]{36})', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const fields = ['title', 'description', 'category', 'city', 'address', 'price', 'bedrooms', 'bathrooms', 'area', 'image_url', 'images', 'amenities', 'lat', 'lng'];
    const updates: string[] = [];
    const values: unknown[] = [];
    for (const field of fields) {
      if (req.body[field] !== undefined) {
        values.push(field === 'images' || field === 'amenities' ? JSON.stringify(req.body[field]) : req.body[field]);
        updates.push(`${field} = $${values.length}`);
      }
    }
    if (updates.length === 0) return res.status(400).json({ error: 'No property fields supplied.' });
    values.push(req.params.id, req.auth?.id);
    const result = await query(
      `UPDATE properties SET ${updates.join(', ')} WHERE id = $${values.length - 1} AND landlord_id = $${values.length} RETURNING *`,
      values,
    );
    if (result.rowCount === 0) return res.status(404).json({ error: 'Property not found or access denied.' });
    clearCachePattern('properties.');
    res.json({ data: normalizePropertyRow(result.rows[0] as Record<string, unknown>) });
  } catch (error) {
    next(error);
  }
});

export default router;

