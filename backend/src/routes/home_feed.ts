import { Router, Request, Response, NextFunction } from 'express';
import { FeedService, FeedContext, FeedSection } from '../services/feed.js';

const router = Router();

// Minimal normalize function borrowed from properties.ts
function normalizePropertyRow(property: Record<string, unknown>): Record<string, unknown> {
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
    const campusId = req.query.campusId as string;
    const limit = req.query.limit ? parseInt(req.query.limit as string) : 20;
    
    // Auth context (if any)
    const userId = (req as any).user?.id;

    const context: FeedContext = {
      lat,
      lng,
      radiusKm,
      campusId,
      userId
    };

    const sections = await FeedService.generateFeed(context, limit);

    // Normalize items
    const normalizedSections = sections.map((sec: FeedSection) => ({
      ...sec,
      items: sec.items.map((item: any) => normalizePropertyRow(item))
    }));

    res.json({
      data: {
        schemaVersion: 1,
        generatedAt: new Date().toISOString(),
        context: {
          source: lat && lng ? 'device' : 'none',
          campusId: campusId || 'optional',
          radiusKm: radiusKm || 5
        },
        sections: normalizedSections,
        nextCursor: null
      }
    });
  } catch (error) {
    console.error('Error generating home feed:', error);
    next(error);
  }
});

export default router;
