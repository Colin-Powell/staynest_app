import { Router, Request, Response, NextFunction } from 'express';
import { query } from '../db.js';

const router = Router();

router.get('/search', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const rawQuery = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    if (rawQuery.length < 2) return res.json({ data: [] });

    const normalized = rawQuery.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
    const like = `%${normalized}%`;
    const startsWith = `${normalized}%`;
    const nearLat = typeof req.query.lat === 'string' ? Number(req.query.lat) : null;
    const nearLng = typeof req.query.lng === 'string' ? Number(req.query.lng) : null;

    const result = await query(
      `SELECT id, name, type, country, county, sub_county, town, ward,
              neighborhood, estate_village, road, landmark, latitude, longitude,
              aliases
       FROM locations
       WHERE normalized_name LIKE $1
          OR normalized_name LIKE $2
          OR EXISTS (
            SELECT 1 FROM jsonb_array_elements_text(aliases) alias
            WHERE lower(alias) LIKE $1 OR lower(alias) LIKE $2
          )
       ORDER BY
         CASE WHEN normalized_name = $3 THEN 0
              WHEN normalized_name LIKE $2 THEN 1
              ELSE 2 END,
         CASE WHEN $4::numeric IS NULL OR latitude IS NULL OR longitude IS NULL THEN 1
              ELSE 6371 * 2 * ASIN(SQRT(
                POWER(SIN(RADIANS(latitude - $4::numeric) / 2), 2) +
                COS(RADIANS($4::numeric)) * COS(RADIANS(latitude)) *
                POWER(SIN(RADIANS(longitude - $5::numeric) / 2), 2)
              )) END
       LIMIT 12`,
      [like, startsWith, normalized, nearLat, nearLng],
    );

    return res.json({ data: result.rows });
  } catch (err) {
    next(err);
  }
});

export default router;