import { Router, Request, Response, NextFunction } from 'express';
import { query } from '../db.js';
import { getCache, setCache } from '../services/cache.js';
import { requireAuth, authorize } from '../middleware/auth.js';
import jwt from 'jsonwebtoken';
import { env } from '../config.js';

const router = Router();

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

    // Build ordering - prefer history categories, then proximity if lat/lng provided, then recent
    const orderParts: string[] = [];
    if (history.length > 0) {
      // param will be added below as array
      params.push(history);
      orderParts.push(`(CASE WHEN p.category = ANY($${params.length}) THEN 0 ELSE 1 END)`);
    }
    if (lat != null && lng != null) {
      params.push(lat, lng);
      // prefer rows with lat/lng populated, then by simple Manhattan distance
      orderParts.push(`(CASE WHEN p.lat IS NULL OR p.lng IS NULL THEN 1 ELSE 0 END)`);
      orderParts.push(`(ABS(COALESCE(p.lat,0) - $${params.length - 1}) + ABS(COALESCE(p.lng,0) - $${params.length}))`);
    }

    const orderClause = orderParts.length > 0 ? `${orderParts.join(', ')}, p.created_at DESC` : 'p.created_at DESC';

    const result = await query(
      `SELECT p.id,
              p.title,
              p.description,
              p.category,
              p.city,
              p.price,
              p.bedrooms,
              p.bathrooms,
              p.area,
              p.image_url,
              p.lat,
              p.lng,
              u.id AS landlord_id,
              u.name AS landlord_name,
              u.email AS landlord_email
       FROM properties p
       LEFT JOIN users u ON u.id = p.landlord_id
       ${whereClause}
       ORDER BY ${orderClause}`,
      params,
    );

    if (conditions.length === 0) {
      setCache(cacheKey, result.rows, 60_000);
    }

    res.set('Cache-Control', 'public, max-age=60, stale-while-revalidate=30');
    res.json({ data: result.rows });
  } catch (error) {
    next(error);
  }
});

// Recommendations endpoint: prioritizes search history, tenant profile and proximity when available
router.get('/recommendations', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const lat = typeof req.query.lat === 'string' ? Number(req.query.lat) : undefined;
    const lng = typeof req.query.lng === 'string' ? Number(req.query.lng) : undefined;
    const historyRaw = typeof req.query.history === 'string' ? req.query.history.trim() : undefined;
    const history = historyRaw ? historyRaw.split(',').map((s) => s.trim()).filter(Boolean) : [];

    // Try to extract user id from Authorization header (optional)
    let userId: string | undefined;
    const authHeader = typeof req.headers.authorization === 'string' ? req.headers.authorization : undefined;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      try {
        const payload = jwt.verify(token, env.jwtSecret) as any;
        userId = payload?.id;
      } catch (_) {
        // ignore invalid token for recommendations; proceed unauthenticated
      }
    }

    const cacheKey = `properties.recommendations|lat=${lat ?? ''}|lng=${lng ?? ''}|history=${history.join('|')}|user=${userId ?? ''}`;
    const cached = getCache<any[]>(cacheKey);
    if (cached) return res.json({ data: cached, cached: true });

    // Optionally load tenant profile
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

    // If profile opted in and provided budget, filter by budget
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
      `SELECT p.id, p.title, p.description, p.category, p.city, p.price, p.bedrooms, p.bathrooms, p.area, p.image_url, p.lat, p.lng
       FROM properties p
       ${whereClause}
       ORDER BY ${orderClause}
       LIMIT 12`,
      params,
    );

    setCache(cacheKey, result.rows, 30_000);
    res.json({ data: result.rows });
  } catch (error) {
    next(error);
  }
});

// Get current user's (landlord) properties
router.get('/me', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      `SELECT p.id,
              p.title,
              p.description,
              p.category,
              p.city,
              p.price,
              p.bedrooms,
              p.bathrooms,
              p.area,
              p.image_url,
              p.lat,
              p.lng,
              p.created_at,
              p.created_at AS updated_at,
              u.id AS landlord_id,
              u.name AS landlord_name,
              u.email AS landlord_email
       FROM properties p
       LEFT JOIN users u ON u.id = p.landlord_id
       WHERE p.landlord_id = $1
       ORDER BY p.created_at DESC`,
      [req.auth?.id],
    );

    res.json({ data: result.rows });
  } catch (error) {
    next(error);
  }
});

router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      `SELECT p.id,
              p.title,
              p.description,
              p.category,
              p.city,
              p.price,
              p.bedrooms,
              p.bathrooms,
              p.area,
              p.image_url,
              p.lat,
              p.lng,
              u.id AS landlord_id,
              u.name AS landlord_name,
              u.email AS landlord_email
       FROM properties p
       LEFT JOIN users u ON u.id = p.landlord_id
       WHERE p.id = $1
       LIMIT 1`,
      [req.params.id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Property not found.' });
    }

    res.json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

router.post('/', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { title, description, category, city, price, bedrooms, bathrooms, area, image_url, lat, lng } = req.body as Record<string, unknown>;
    if (!title || !description || !category || !city || price == null || bedrooms == null || bathrooms == null || area == null || !image_url) {
      return res.status(400).json({ error: 'All property fields are required.' });
    }

    const result = await query(
      `INSERT INTO properties (title, description, category, city, price, bedrooms, bathrooms, area, image_url, lat, lng, landlord_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
       RETURNING id, title, description, category, city, price, bedrooms, bathrooms, area, image_url, lat, lng`,
      [
        title,
        description,
        category,
        city,
        Number(price),
        Number(bedrooms),
        Number(bathrooms),
        Number(area),
        image_url,
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

export default router;
