import { Router } from 'express';
import { FeedService } from '../services/feed.js';
const router = Router();
// Minimal normalize function borrowed from properties.ts
function normalizePropertyRow(property) {
    let images = property.images;
    if (!property.status) {
        property.status = 'pending_review';
    }
    if (images === null)
        images = undefined;
    if (typeof images === 'string') {
        try {
            images = JSON.parse(images);
        }
        catch {
            images = [];
        }
    }
    if (!Array.isArray(images) || images.length === 0) {
        if (property.image_url) {
            property.images = [property.image_url];
        }
        else {
            property.images = [];
        }
    }
    else {
        property.images = images;
    }
    let amenities = property.amenities;
    if (amenities === null)
        amenities = undefined;
    if (typeof amenities === 'string') {
        try {
            amenities = JSON.parse(amenities);
        }
        catch {
            amenities = [];
        }
    }
    if (!Array.isArray(amenities)) {
        property.amenities = [];
    }
    return property;
}
router.get('/', async (req, res, next) => {
    try {
        const lat = req.query.lat ? parseFloat(req.query.lat) : undefined;
        const lng = req.query.lng ? parseFloat(req.query.lng) : undefined;
        const radiusKm = req.query.radiusKm ? parseFloat(req.query.radiusKm) : undefined;
        const campusId = typeof req.query.campusId === 'string' ? req.query.campusId : undefined;
        const locationId = typeof req.query.locationId === 'string' ? req.query.locationId : undefined;
        const category = typeof req.query.category === 'string' ? req.query.category.trim() : undefined;
        const limit = Math.min(Math.max(req.query.limit ? parseInt(req.query.limit) : 20, 1), 50);
        // Auth context (if any)
        const userId = req.user?.id;
        const context = {
            lat,
            lng,
            radiusKm,
            campusId,
            locationId,
            category,
            userId
        };
        const sections = await FeedService.generateFeed(context, limit);
        // Normalize items
        const normalizedSections = sections.map((sec) => ({
            ...sec,
            items: sec.items.map((item) => normalizePropertyRow(item))
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
                nextCursor: null
            }
        });
    }
    catch (error) {
        console.error('Error generating home feed:', error);
        next(error);
    }
});
export default router;
//# sourceMappingURL=home_feed.js.map