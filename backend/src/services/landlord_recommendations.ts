import { query } from '../db.js';

export const LANDLORD_RECOMMENDATION_THRESHOLDS = {
  unansweredHours: 12,
  lowConversionMinimumViews: 30,
  lowConversionMaximumRate: 0.02,
  sufficientPhotoCount: 3,
  decliningMinimumPreviousViews: 5,
  decliningMaximumRatio: 0.7,
  promisingMinimumViews: 30,
  promisingMinimumConversations: 3,
} as const;

export interface LandlordRecommendation {
  id: string;
  type:
    | 'unanswered_enquiry'
    | 'pending_booking'
    | 'low_conversion'
    | 'incomplete_listing'
    | 'pending_approval'
    | 'declining_views'
    | 'insufficient_photos'
    | 'unavailable_property'
    | 'promising_listing';
  title: string;
  body: string;
  priority: 'high' | 'medium' | 'low';
  actionUrl: string;
  actionText: string;
  conversationId?: string;
  bookingId?: string;
  property?: {
    id: string;
    title: string;
    imageUrl?: string;
  };
  metrics?: Record<string, unknown>;
}

export async function generateLandlordRecommendations(landlordId: string): Promise<LandlordRecommendation[]> {
  const recommendations: LandlordRecommendation[] = [];

  try {
    // Property-linked conversations use one record per property and tenant pair.
    const unansweredRes = await query(
      `WITH last_msgs AS (
         SELECT DISTINCT ON (m.conversation_id)
           m.conversation_id,
           m.from_user_id,
           m.text,
           m.created_at
         FROM messages m
         JOIN message_conversations mc ON mc.id = m.conversation_id
         WHERE mc.property_id IN (SELECT id FROM properties WHERE landlord_id = $1)
           AND mc.context_type = 'property'
         ORDER BY m.conversation_id, m.created_at DESC
       )
       SELECT lm.conversation_id, lm.text, lm.created_at, p.id AS property_id, p.title AS property_title, p.image_url
       FROM last_msgs lm
       JOIN message_conversations mc ON mc.id = lm.conversation_id
       JOIN properties p ON p.id = mc.property_id
       WHERE lm.from_user_id != $1
        AND lm.created_at <= NOW() - ($2::int * INTERVAL '1 hour')
       ORDER BY lm.created_at ASC
       LIMIT 3`,
      [landlordId, LANDLORD_RECOMMENDATION_THRESHOLDS.unansweredHours]
    );

    for (const r of unansweredRes.rows) {
      recommendations.push({
        id: `unanswered_${r.conversation_id}`,
        type: 'unanswered_enquiry',
        title: 'Unanswered Tenant Enquiry',
        body: `The latest message about "${r.property_title}" was received more than ${LANDLORD_RECOMMENDATION_THRESHOLDS.unansweredHours} hours ago.`,
        priority: 'high',
        actionUrl: `/messages?conversationId=${r.conversation_id}`,
        actionText: 'Reply in Chat',
        conversationId: String(r.conversation_id),
        property: {
          id: String(r.property_id),
          title: String(r.property_title),
          imageUrl: r.image_url ? String(r.image_url) : undefined,
        },
      });
    }

    // 2. Check for pending booking requests needing attention
    const pendingBookingsRes = await query(
      `SELECT b.id, b.property_id, p.title AS property_title, p.image_url, b.created_at
       FROM bookings b
       JOIN properties p ON p.id = b.property_id
       WHERE b.landlord_id = $1
         AND b.status = 'pending'
        AND b.check_out_date >= CURRENT_DATE
       ORDER BY b.created_at ASC
       LIMIT 3`,
      [landlordId]
    );

    for (const b of pendingBookingsRes.rows) {
      recommendations.push({
        id: `pending_booking_${b.id}`,
        type: 'pending_booking',
        title: 'Pending Booking Request',
        body: `A booking request for "${b.property_title}" is awaiting your confirmation.`,
        priority: 'high',
        actionUrl: `/bookings`,
        actionText: 'Review Booking',
        bookingId: String(b.id),
        property: {
          id: String(b.property_id),
          title: String(b.property_title),
          imageUrl: b.image_url ? String(b.image_url) : undefined,
        },
      });
    }

    const lowConversionRes = await query(
      `SELECT p.id, p.title, p.image_url,
              COUNT(DISTINCT puv.user_id)::int AS views,
              COUNT(DISTINCT mc.id) AS enquiry_count
       FROM properties p
       JOIN property_unique_views puv
         ON puv.property_id = p.id
        AND puv.viewed_date >= CURRENT_DATE - 29
        AND puv.viewed_date <= CURRENT_DATE
       LEFT JOIN message_conversations mc
         ON mc.property_id = p.id
        AND mc.context_type = 'property'
        AND mc.created_at >= CURRENT_DATE - 29
        AND mc.created_at < CURRENT_DATE + 1
       WHERE p.landlord_id = $1
         AND p.status = 'approved'
         AND p.availability_status = 'available'
       GROUP BY p.id, p.title, p.image_url
       HAVING COUNT(DISTINCT puv.user_id) >= $2
          AND COUNT(DISTINCT mc.id)::float / NULLIF(COUNT(DISTINCT puv.user_id), 0) < $3
       LIMIT 2`,
      [
        landlordId,
        LANDLORD_RECOMMENDATION_THRESHOLDS.lowConversionMinimumViews,
        LANDLORD_RECOMMENDATION_THRESHOLDS.lowConversionMaximumRate,
      ]
    );

    for (const lc of lowConversionRes.rows) {
      recommendations.push({
        id: `low_conv_${lc.id}`,
        type: 'low_conversion',
        title: 'Optimize Property Listing',
        body: `"${lc.title}" had ${lc.views} distinct viewers but few property-linked conversations in the last 30 days. Consider reviewing its photos, price, description, amenities, and location.`,
        priority: 'medium',
        actionUrl: `/properties/edit/${lc.id}`,
        actionText: 'Edit Listing',
        metrics: {
          views: Number(lc.views),
          propertyLinkedConversations: Number(lc.enquiry_count),
          threshold: LANDLORD_RECOMMENDATION_THRESHOLDS.lowConversionMaximumRate,
        },
        property: {
          id: String(lc.id),
          title: String(lc.title),
          imageUrl: lc.image_url ? String(lc.image_url) : undefined,
        },
      });
    }

    // Incomplete properties or pending approval
    const pendingPropertiesRes = await query(
      `SELECT id, title, image_url, status
       FROM properties
       WHERE landlord_id = $1
         AND status IN ('pending_review', 'draft')
       LIMIT 2`,
      [landlordId]
    );

    for (const pr of pendingPropertiesRes.rows) {
      recommendations.push({
        id: `status_${pr.id}`,
        type: 'pending_approval',
        title: pr.status === 'draft' ? 'Finish Listing Draft' : 'Listing Under Review',
        body: pr.status === 'draft'
          ? `Complete details for "${pr.title}" and submit it for publication.`
          : `"${pr.title}" is being reviewed by our team and will be visible to tenants soon.`,
        priority: pr.status === 'draft' ? 'medium' : 'low',
        actionUrl: `/properties/edit/${pr.id}`,
        actionText: pr.status === 'draft' ? 'Complete Listing' : 'View Details',
        property: {
          id: String(pr.id),
          title: String(pr.title),
          imageUrl: pr.image_url ? String(pr.image_url) : undefined,
        },
      });
    }

    const [incompleteRes, photoRes, decliningRes, unavailableRes, promisingRes] =
      await Promise.all([
        query(
          `SELECT id, title, image_url
           FROM properties
           WHERE landlord_id = $1
             AND status = 'approved'
             AND (
               NULLIF(BTRIM(COALESCE(description, '')), '') IS NULL
               OR COALESCE(price, 0) <= 0
               OR NULLIF(BTRIM(COALESCE(address, '')), '') IS NULL
             )
           ORDER BY updated_at DESC NULLS LAST
           LIMIT 3`,
          [landlordId],
        ),
        query(
          `SELECT id, title, image_url,
                CASE WHEN jsonb_typeof(images) = 'array' THEN
                  CASE WHEN jsonb_array_length(images) > 0
                  THEN jsonb_array_length(images)
                  WHEN image_url IS NOT NULL AND BTRIM(image_url) <> ''
                  THEN 1 ELSE 0 END
                WHEN image_url IS NOT NULL AND BTRIM(image_url) <> ''
                THEN 1 ELSE 0 END AS photo_count
           FROM properties
           WHERE landlord_id = $1
             AND status = 'approved'
               AND CASE WHEN jsonb_typeof(images) = 'array' THEN
                CASE WHEN jsonb_array_length(images) > 0
                  THEN jsonb_array_length(images)
                  WHEN image_url IS NOT NULL AND BTRIM(image_url) <> ''
                  THEN 1 ELSE 0 END
                 WHEN image_url IS NOT NULL AND BTRIM(image_url) <> ''
                 THEN 1 ELSE 0 END < $2
           ORDER BY updated_at DESC NULLS LAST
           LIMIT 3`,
          [landlordId, LANDLORD_RECOMMENDATION_THRESHOLDS.sufficientPhotoCount],
        ),
        query(
          `SELECT p.id, p.title, p.image_url,
                  COUNT(*) FILTER (
                    WHERE v.viewed_date >= CURRENT_DATE - 13
                  )::int AS current_views,
                  COUNT(*) FILTER (
                    WHERE v.viewed_date >= CURRENT_DATE - 27
                      AND v.viewed_date < CURRENT_DATE - 13
                  )::int AS previous_views
           FROM properties p
           JOIN property_unique_views v ON v.property_id = p.id
           WHERE p.landlord_id = $1
             AND p.status = 'approved'
             AND v.viewed_date >= CURRENT_DATE - 27
             AND v.viewed_date <= CURRENT_DATE
           GROUP BY p.id, p.title, p.image_url
           HAVING COUNT(*) FILTER (
             WHERE v.viewed_date >= CURRENT_DATE - 27
               AND v.viewed_date < CURRENT_DATE - 13
           ) >= $2
           AND COUNT(*) FILTER (
             WHERE v.viewed_date >= CURRENT_DATE - 13
           ) < COUNT(*) FILTER (
             WHERE v.viewed_date >= CURRENT_DATE - 27
               AND v.viewed_date < CURRENT_DATE - 13
           ) * $3::numeric
           ORDER BY current_views ASC
           LIMIT 3`,
          [
            landlordId,
            LANDLORD_RECOMMENDATION_THRESHOLDS.decliningMinimumPreviousViews,
            LANDLORD_RECOMMENDATION_THRESHOLDS.decliningMaximumRatio,
          ],
        ),
        query(
          `SELECT id, title, image_url, availability_status
           FROM properties
           WHERE landlord_id = $1
             AND availability_status IN ('unavailable', 'rented', 'maintenance')
           ORDER BY updated_at DESC NULLS LAST
           LIMIT 3`,
          [landlordId],
        ),
        query(
          `SELECT p.id, p.title, p.image_url,
                  COUNT(DISTINCT v.user_id)::int AS views,
                  COUNT(DISTINCT mc.id)::int AS conversations
           FROM properties p
           JOIN property_unique_views v
             ON v.property_id = p.id
            AND v.viewed_date >= CURRENT_DATE - 29
            AND v.viewed_date <= CURRENT_DATE
           JOIN message_conversations mc
             ON mc.property_id = p.id
            AND mc.context_type = 'property'
            AND mc.created_at >= CURRENT_DATE - 29
            AND mc.created_at < CURRENT_DATE + 1
           WHERE p.landlord_id = $1
             AND p.status = 'approved'
             AND p.availability_status = 'available'
           GROUP BY p.id, p.title, p.image_url
           HAVING COUNT(DISTINCT v.user_id) >= $2
              AND COUNT(DISTINCT mc.id) >= $3
           ORDER BY conversations DESC, views DESC
           LIMIT 2`,
          [
            landlordId,
            LANDLORD_RECOMMENDATION_THRESHOLDS.promisingMinimumViews,
            LANDLORD_RECOMMENDATION_THRESHOLDS.promisingMinimumConversations,
          ],
        ),
      ]);

    for (const property of incompleteRes.rows) {
      recommendations.push({
        id: `incomplete_${property.id}`,
        type: 'incomplete_listing',
        title: 'Complete listing details',
        body: `"${property.title}" is missing a description, valid price, or address.`,
        priority: 'medium',
        actionUrl: `/properties/edit/${property.id}`,
        actionText: 'Edit Listing',
        property: {
          id: String(property.id),
          title: String(property.title),
          imageUrl: property.image_url ? String(property.image_url) : undefined,
        },
      });
    }

    for (const property of photoRes.rows) {
      recommendations.push({
        id: `photos_${property.id}`,
        type: 'insufficient_photos',
        title: 'Add property photos',
        body: `"${property.title}" has ${property.photo_count} photos; at least ${LANDLORD_RECOMMENDATION_THRESHOLDS.sufficientPhotoCount} are recommended for a complete listing.`,
        priority: 'medium',
        actionUrl: `/properties/edit/${property.id}`,
        actionText: 'Add Photos',
        metrics: { photoCount: Number(property.photo_count) },
        property: {
          id: String(property.id),
          title: String(property.title),
          imageUrl: property.image_url ? String(property.image_url) : undefined,
        },
      });
    }

    for (const property of decliningRes.rows) {
      recommendations.push({
        id: `declining_${property.id}`,
        type: 'declining_views',
        title: 'Views are declining',
        body: `"${property.title}" received fewer unique views in the last 14 days than the previous 14 days.`,
        priority: 'medium',
        actionUrl: `/properties/edit/${property.id}`,
        actionText: 'Review Listing',
        metrics: {
          currentViews: Number(property.current_views),
          previousViews: Number(property.previous_views),
        },
        property: {
          id: String(property.id),
          title: String(property.title),
          imageUrl: property.image_url ? String(property.image_url) : undefined,
        },
      });
    }

    for (const property of unavailableRes.rows) {
      recommendations.push({
        id: `availability_${property.id}`,
        type: 'unavailable_property',
        title: 'Review property availability',
        body: `"${property.title}" is marked ${property.availability_status}. Confirm this still reflects its booking availability.`,
        priority: 'low',
        actionUrl: `/properties/edit/${property.id}`,
        actionText: 'Review Status',
        property: {
          id: String(property.id),
          title: String(property.title),
          imageUrl: property.image_url ? String(property.image_url) : undefined,
        },
      });
    }

    for (const property of promisingRes.rows) {
      recommendations.push({
        id: `promising_${property.id}`,
        type: 'promising_listing',
        title: 'Strong listing engagement',
        body: `"${property.title}" has meaningful recent views and property-linked conversations.`,
        priority: 'low',
        actionUrl: `/properties/${property.id}`,
        actionText: 'View Performance',
        metrics: {
          views: Number(property.views),
          propertyLinkedConversations: Number(property.conversations),
        },
        property: {
          id: String(property.id),
          title: String(property.title),
          imageUrl: property.image_url ? String(property.image_url) : undefined,
        },
      });
    }
  } catch (err) {
    console.error('[LandlordRecommendations] Error building recommendations:', err);
  }

  return recommendations;
}
