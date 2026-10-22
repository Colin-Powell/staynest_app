import { Router, Request, Response, NextFunction } from 'express';
import { FeedService, FeedContext, FeedSection } from '../services/feed.js';
import { normalizePublicPropertyCategory } from '../services/property_category.js';

const router = Router();

// Minimal normalize function borrowed from properties.ts
function normalizePropertyRow(property: Record<string, unknown>): Record<string, unknown> {
  property.category = normalizePublicPropertyCategory(property.category);
  let images = property.images;
  if (!property.status) {
    property.status = 'pending_review';
  }
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

router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const lat = req.query.lat ? parseFloat(req.query.lat as string) : undefined;
    const lng = req.query.lng ? parseFloat(req.query.lng as string) : undefined;
    const radiusKm = req.query.radiusKm ? parseFloat(req.query.radiusKm as string) : undefined;
    const campusId = typeof req.query.campusId === 'string' ? req.query.campusId : undefined;
    const locationId = typeof req.query.locationId === 'string' ? req.query.locationId : undefined;
    const category = typeof req.query.category === 'string' ? req.query.category.trim() : undefined;
    const limit = Math.min(Math.max(req.query.limit ? parseInt(req.query.limit as string) : 20, 1), 20);
    const offset = Math.max(0, req.query.cursor ? parseInt(req.query.cursor as string, 10) || 0 : 0);
    
    // Auth context (if any)
    const userId = (req as any).user?.id;

    const context: FeedContext = {
      lat,
      lng,
      radiusKm,
      campusId,
      locationId,
      category,
      userId
    };

    const fetchLimit = Math.min(offset + limit + 1, 50);
    const sections = await FeedService.generateFeed(context, fetchLimit);

    const pagedSections = sections.flatMap((sec: FeedSection) => {
      const items = sec.items.slice(offset, offset + limit);
      if (items.length === 0) return [];
      return [{
        ...sec,
        items,
        hasMore: sec.items.length > offset + limit,
        nextCursor: sec.items.length > offset + limit
          ? String(offset + limit)
          : null,
      }];
    });

    // Normalize items
    const normalizedSections = pagedSections.map((sec: FeedSection) => ({
      ...sec,
      items: sec.items.map((item: any) => normalizePropertyRow(item))
    }));

    res.json({
      data: {
        schemaVersion: 1,
        generatedAt: new Date().toISOString(),
        context: {
            source: lat != null && lng != null
              ? 'device'
              : (campusId || locationId ? 'selected_location' : 'none'),
            campusId: campusId || '',
            locationId: locationId || '',
            radiusKm: radiusKm || 5,
            category: category || 'All'
        },
        sections: normalizedSections,
        nextCursor: normalizedSections.some((sec) => sec.hasMore)
          ? String(offset + limit)
          : null,
      }
    });
  } catch (error) {
    console.error('Error generating home feed:', error);
    next(error);
  }
});

export default router;
