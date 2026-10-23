import { Router } from "express";
import { query } from "../db.js";
import { env } from "../config.js";
import { authorize, requireAuth } from "../middleware/auth.js";
import { queueUserPush } from "../services/queue.js";
import { queuePropertyInquiryEmail } from "../services/email.js";
import {
  isPropertyEligibleForMessaging,
  orderConversationParticipants,
} from "../services/conversation_policy.js";

import { emitDirectConversationPresence, ioInstance } from "../socket.js";

const router = Router();
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function getOrCreateGeneralConversation(first: string, second: string) {
  const [participantOneId, participantTwoId] = orderConversationParticipants(
    first,
    second,
  );
  const result = await query(
    `INSERT INTO message_conversations (
       participant_one_id, participant_two_id, context_type
     ) VALUES ($1, $2, 'general')
     ON CONFLICT (participant_one_id, participant_two_id)
       WHERE context_type = 'general'
     DO UPDATE SET updated_at = message_conversations.updated_at
     RETURNING id`,
    [participantOneId, participantTwoId],
  );
  return result.rows[0].id as string;
}

const CONVERSATION_CONTEXT_SELECT = `
  SELECT c.id AS conversation_id,
         c.participant_one_id,
         c.participant_two_id,
         c.context_type,
         c.property_id,
         p.landlord_id AS property_landlord_id,
         p.title AS property_title,
         COALESCE(NULLIF(p.address, ''), NULLIF(p.town, ''),
                  NULLIF(p.city, ''), NULLIF(p.county, ''), '') AS property_location,
         p.price AS property_price,
         p.availability_status AS property_availability_status,
         p.image_url AS property_image_url,
         p.images AS property_images
    FROM message_conversations c
    LEFT JOIN properties p
      ON p.id = c.property_id
     AND p.landlord_id IN (c.participant_one_id, c.participant_two_id)`;

function propertyContext(row: Record<string, unknown>) {
  if (!row.property_id) return null;
  return {
    id: row.property_id,
    title: row.property_title,
    location: row.property_location,
    price: row.property_price,
    availability_status: row.property_availability_status,
    image_url: row.property_image_url,
    images: row.property_images,
  };
}

function getPropertyEmailImageUrl(row: Record<string, unknown>) {
  let images = row.property_images;
  if (typeof images === "string") {
    try {
      images = JSON.parse(images);
    } catch {
      images = [];
    }
  }

  const imageEntries = Array.isArray(images) ? images : [];
  const candidates = [
    row.property_image_url,
    ...imageEntries.map((image) =>
      typeof image === "string"
        ? image
        : image && typeof image === "object" && "url" in image
          ? image.url
          : null,
    ),
  ];

  for (const candidate of candidates) {
    if (typeof candidate !== "string" || !candidate.trim()) continue;
    const imageUrl = candidate.trim();
    if (/^https?:\/\//i.test(imageUrl)) return imageUrl;

    if (imageUrl.startsWith("/") || imageUrl.startsWith("uploads/")) {
      try {
        const apiOrigin = env.apiBaseUrl
          .replace(/\/+$/, "")
          .replace(/\/api$/i, "");
        return new URL(imageUrl, `${apiOrigin}/`).toString();
      } catch {
        continue;
      }
    }

    if (env.cloudinaryCloudName) {
      const publicId = imageUrl.includes(".") ? imageUrl : `${imageUrl}.jpg`;
      return `https://res.cloudinary.com/${env.cloudinaryCloudName}/image/upload/${publicId}`;
    }
  }

  return undefined;
}

router.post(
  "/conversations/initiate",
  requireAuth,
  authorize("tenant"),
  async (req, res, next) => {
    try {
      const propertyId = req.body?.property_id?.toString().trim();
      if (!propertyId || !UUID_PATTERN.test(propertyId)) {
        return res
          .status(400)
          .json({ error: "A valid property_id is required." });
      }

      const propertyResult = await query<{
        id: string;
        landlord_id: string;
        status: string | null;
      }>(
        `SELECT id, landlord_id, status
         FROM properties
        WHERE id = $1
        LIMIT 1`,
        [propertyId],
      );
      const property = propertyResult.rows[0];
      if (!property || !isPropertyEligibleForMessaging(property.status)) {
        return res.status(404).json({ error: "Property not found." });
      }

      const tenantId = req.auth!.id;
      if (property.landlord_id === tenantId) {
        return res
          .status(403)
          .json({ error: "You cannot message yourself about this property." });
      }

      const [participantOneId, participantTwoId] =
        orderConversationParticipants(tenantId, property.landlord_id);
      const conversationResult = await query(
        `INSERT INTO message_conversations (
         participant_one_id, participant_two_id, property_id, context_type
       ) VALUES ($1, $2, $3, 'property')
       ON CONFLICT (participant_one_id, participant_two_id, property_id)
         WHERE context_type = 'property' AND property_id IS NOT NULL
       DO UPDATE SET updated_at = message_conversations.updated_at
       RETURNING id`,
        [participantOneId, participantTwoId, property.id],
      );

      const conversationId = conversationResult.rows[0].id as string;
      const contextResult = await query(
        `${CONVERSATION_CONTEXT_SELECT}
       WHERE c.id = $1
         AND (c.participant_one_id = $2 OR c.participant_two_id = $2)`,
        [conversationId, tenantId],
      );
      const context = contextResult.rows[0];
      const partnerId =
        context.participant_one_id === tenantId
          ? context.participant_two_id
          : context.participant_one_id;
      const partnerResult = await query(
        "SELECT id AS user_id, name AS user_name, avatar AS user_avatar FROM users WHERE id = $1 LIMIT 1",
        [partnerId],
      );

      return res.status(200).json({
        data: {
          conversation: {
            ...partnerResult.rows[0],
            conversation_id: context.conversation_id,
            context_type: context.context_type,
            property: propertyContext(context),
          },
        },
      });
    } catch (error) {
      next(error);
    }
  },
);

// Save a message to database
router.post("/", requireAuth, async (req, res, next) => {
  try {
    const { to_user_id, conversation_id, property_id, text } = req.body as {
      to_user_id?: string;
      conversation_id?: string;
      property_id?: string;
      text?: string;
    };

    if (!text?.trim() || (!conversation_id && !to_user_id)) {
      return res
        .status(400)
        .json({
          error:
            "A recipient or conversation_id and non-empty text are required.",
        });
    }
    if (property_id) {
      return res
        .status(400)
        .json({
          error: "Start a property conversation before sending a message.",
        });
    }

    const from_user_id = req.auth!.id;
    let recipientId = to_user_id;
    let conversationId = conversation_id;

    if (conversation_id) {
      if (!UUID_PATTERN.test(conversation_id)) {
        return res.status(400).json({ error: "Invalid conversation_id." });
      }
      const conversationResult = await query<{
        participant_one_id: string;
        participant_two_id: string;
      }>(
        `SELECT participant_one_id, participant_two_id
           FROM message_conversations
          WHERE id = $1
            AND (participant_one_id = $2 OR participant_two_id = $2)
          LIMIT 1`,
        [conversation_id, from_user_id],
      );
      const conversation = conversationResult.rows[0];
      if (!conversation)
        return res.status(404).json({ error: "Conversation not found." });
      recipientId =
        conversation.participant_one_id === from_user_id
          ? conversation.participant_two_id
          : conversation.participant_one_id;
      if (to_user_id && to_user_id !== recipientId) {
        return res
          .status(403)
          .json({ error: "Recipient does not match this conversation." });
      }
    }

    if (!recipientId || !UUID_PATTERN.test(recipientId)) {
      return res.status(400).json({ error: "A valid recipient is required." });
    }

    // Verify both users exist and get sender's name
    const [toUserResult, fromUserResult] = await Promise.all([
      query("SELECT id, name, email, role FROM users WHERE id = $1 LIMIT 1", [
        recipientId,
      ]),
      query("SELECT name, role FROM users WHERE id = $1 LIMIT 1", [
        from_user_id,
      ]),
    ]);

    if (toUserResult.rowCount === 0) {
      return res.status(404).json({ error: "Recipient not found." });
    }

    if (!conversationId) {
      conversationId = await getOrCreateGeneralConversation(
        from_user_id,
        recipientId,
      );
    }

    const from_name = fromUserResult.rows[0]?.name || "Someone";
    const contextResult = await query(
      `${CONVERSATION_CONTEXT_SELECT} WHERE c.id = $1`,
      [conversationId],
    );
    const conversationContext = contextResult.rows[0] ?? {};
    const isTenantPropertyInquiry =
      conversationContext.context_type === "property" &&
      conversationContext.property_landlord_id === recipientId &&
      fromUserResult.rows[0]?.role === "tenant";
    let isFirstPropertyInquiry = false;
    if (isTenantPropertyInquiry) {
      const priorMessageResult = await query(
        "SELECT EXISTS (SELECT 1 FROM messages WHERE conversation_id = $1) AS has_messages",
        [conversationId],
      );
      isFirstPropertyInquiry = !priorMessageResult.rows[0]?.has_messages;
    }

    const result = await query(
      `INSERT INTO messages (conversation_id, from_user_id, to_user_id, text)
       VALUES ($1, $2, $3, $4)
       RETURNING id, conversation_id, from_user_id, to_user_id, text, created_at`,
      [conversationId, from_user_id, recipientId, text.trim()],
    );

    await query(
      "UPDATE message_conversations SET updated_at = now() WHERE id = $1",
      [conversationId],
    );
    const payload = {
      ...result.rows[0],
      property: propertyContext(conversationContext),
    };

    // Emit to recipient over socket
    if (ioInstance && recipientId !== from_user_id) {
      ioInstance.to(`user:${recipientId}`).emit("message", payload);
      void Promise.all([
        emitDirectConversationPresence(from_user_id, recipientId),
        emitDirectConversationPresence(recipientId, from_user_id),
      ]).catch((error) => {
        console.error("[Presence] conversation refresh failed:", error);
      });
    }

    // Send push notification
    if (recipientId !== from_user_id) {
      await queueUserPush(
        recipientId,
        `New message from ${from_name}`,
        text.trim(),
        {
          type: "new_message",
          chatId: from_user_id,
          senderId: from_user_id,
          conversationId,
          propertyId: conversationContext.property_id?.toString(),
          messageId: payload.id.toString(),
        },
      );
    }

    if (isFirstPropertyInquiry) {
      const landlord = toUserResult.rows[0];
      const propertyId = conversationContext.property_id?.toString();
      if (landlord?.email && propertyId) {
        try {
          await queuePropertyInquiryEmail({
            to: landlord.email,
            landlordName: landlord.name || "there",
            tenantName: from_name,
            propertyName: conversationContext.property_title || "your property",
            propertyUrl: `https://staynest.top/properties/${encodeURIComponent(propertyId)}`,
            propertyImageUrl: getPropertyEmailImageUrl(conversationContext),
            message: text.trim(),
            conversationId,
            messageId: payload.id.toString(),
          });
        } catch (error) {
          console.error(
            "[Messages] property inquiry email enqueue failed:",
            error,
          );
        }
      }
    }

    return res.status(201).json({ data: payload });
  } catch (error) {
    next(error);
  }
});

router.get(
  "/conversations/:conversationId/messages",
  requireAuth,
  async (req, res, next) => {
    try {
      const { conversationId } = req.params;
      const currentUserId = req.auth!.id;
      const limit = Math.min(
        Math.max(parseInt(req.query.limit as string) || 50, 1),
        100,
      );
      const offset = Math.max(parseInt(req.query.offset as string) || 0, 0);
      if (!UUID_PATTERN.test(conversationId)) {
        return res.status(400).json({ error: "Invalid conversation_id." });
      }

      const conversationResult = await query(
        `${CONVERSATION_CONTEXT_SELECT}
       WHERE c.id = $1
         AND (c.participant_one_id = $2 OR c.participant_two_id = $2)
       LIMIT 1`,
        [conversationId, currentUserId],
      );
      const conversation = conversationResult.rows[0];
      if (!conversation)
        return res.status(404).json({ error: "Conversation not found." });

      const messagesResult = await query(
        `SELECT id, conversation_id, from_user_id, to_user_id, text, created_at
         FROM messages
        WHERE conversation_id = $1
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3`,
        [conversationId, limit, offset],
      );
      const partnerId =
        conversation.participant_one_id === currentUserId
          ? conversation.participant_two_id
          : conversation.participant_one_id;
      const partnerResult = await query(
        "SELECT id AS user_id, name AS user_name, avatar AS user_avatar FROM users WHERE id = $1 LIMIT 1",
        [partnerId],
      );

      return res.json({
        data: {
          conversation: {
            ...partnerResult.rows[0],
            conversation_id: conversation.conversation_id,
            context_type: conversation.context_type,
            property: propertyContext(conversation),
          },
          messages: messagesResult.rows.reverse(),
          count: messagesResult.rowCount,
        },
      });
    } catch (error) {
      next(error);
    }
  },
);

router.delete(
  "/conversations/:conversationId",
  requireAuth,
  async (req, res, next) => {
    try {
      const { conversationId } = req.params;
      if (!UUID_PATTERN.test(conversationId)) {
        return res.status(400).json({ error: "Invalid conversation_id." });
      }
      const result = await query(
        `DELETE FROM message_conversations
        WHERE id = $1
          AND (participant_one_id = $2 OR participant_two_id = $2)`,
        [conversationId, req.auth!.id],
      );
      if (result.rowCount === 0) {
        return res.status(404).json({ error: "Conversation not found." });
      }
      return res.json({ data: { deleted: true } });
    } catch (error) {
      next(error);
    }
  },
);

// Fetch conversation history between two users (paginated)
router.get("/conversation/:userId", requireAuth, async (req, res, next) => {
  try {
    const { userId } = req.params;
    const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);
    const offset = parseInt(req.query.offset as string) || 0;

    const currentUserId = req.auth!.id;
    const [participantOneId, participantTwoId] = orderConversationParticipants(
      currentUserId,
      userId,
    );
    const conversationResult = await query<{ id: string }>(
      `SELECT id
         FROM message_conversations
        WHERE participant_one_id = $1
          AND participant_two_id = $2
          AND context_type = 'general'
        LIMIT 1`,
      [participantOneId, participantTwoId],
    );
    const conversationId = conversationResult.rows[0]?.id;
    if (!conversationId) {
      return res.json({
        data: { conversation_id: null, messages: [], count: 0 },
      });
    }

    const result = await query(
      `SELECT id, conversation_id, from_user_id, to_user_id, text, created_at
       FROM messages
       WHERE conversation_id = $1
       ORDER BY created_at DESC
       LIMIT $2 OFFSET $3`,
      [conversationId, limit, offset],
    );

    return res.json({
      data: {
        conversation_id: conversationId,
        messages: result.rows.reverse(), // Reverse to show oldest first
        count: result.rowCount,
      },
    });
  } catch (error) {
    next(error);
  }
});

router.post("/mark-read", requireAuth, async (req, res, next) => {
  try {
    const currentUserId = req.auth!.id;

    // Interpret payload as "mark all messages from these users as read for me".
    // Frontend currently sends: { user_ids: [...] }
    const { user_ids, conversation_ids } = req.body as {
      user_ids?: string[];
      conversation_ids?: string[];
    };

    const conversationIds = (conversation_ids ?? [])
      .map((value) => value?.toString())
      .filter((value): value is string => Boolean(value));
    if (conversationIds.some((id) => !UUID_PATTERN.test(id))) {
      return res.status(400).json({ error: "Invalid conversation_id." });
    }

    if (conversationIds.length > 0) {
      const authorized = await query<{ id: string }>(
        `SELECT id
           FROM message_conversations
          WHERE id = ANY($1::uuid[])
            AND (participant_one_id = $2 OR participant_two_id = $2)`,
        [conversationIds, currentUserId],
      );
      if (authorized.rowCount !== conversationIds.length) {
        return res.status(403).json({ error: "Conversation access denied." });
      }
      const result = await query(
        `INSERT INTO message_reads (user_id, message_id, read_at)
         SELECT $1, m.id, now()
           FROM messages m
          WHERE m.conversation_id = ANY($2::uuid[])
            AND m.to_user_id = $1
            AND NOT EXISTS (
              SELECT 1 FROM message_reads mr
               WHERE mr.user_id = $1 AND mr.message_id = m.id
            )`,
        [currentUserId, conversationIds],
      );
      return res.status(200).json({ data: { updated: result.rowCount } });
    }

    const partnerIds = (user_ids ?? [])
      .map((v) => v?.toString())
      .filter(Boolean);

    // If no users provided, mark all incoming messages as read.
    if (partnerIds.length === 0) {
      const unreadFromResult = await query(
        `SELECT DISTINCT from_user_id
         FROM messages
         WHERE to_user_id = $1
           AND NOT EXISTS (
             SELECT 1
             FROM message_reads mr
             WHERE mr.user_id = $1
               AND mr.message_id = messages.id
           )`,
        [currentUserId],
      );

      const allPartnerIds = unreadFromResult.rows.map((r) => r.from_user_id);
      if (allPartnerIds.length === 0) {
        return res.status(200).json({ data: { updated: 0 } });
      }

      const now = new Date();

      // Insert read receipts for all unread messages
      const result = await query(
        `INSERT INTO message_reads (user_id, message_id, read_at)
         SELECT $1 as user_id, m.id as message_id, $2 as read_at
         FROM messages m
         WHERE m.to_user_id = $1
           AND m.from_user_id = ANY($3)
           AND NOT EXISTS (
             SELECT 1 FROM message_reads mr
             WHERE mr.user_id = $1 AND mr.message_id = m.id
           )`,
        [currentUserId, now, allPartnerIds],
      );

      return res.status(200).json({ data: { updated: result.rowCount } });
    }

    const now = new Date();

    // Upsert-ish behavior via INSERT ... SELECT + NOT EXISTS
    const result = await query(
      `INSERT INTO message_reads (user_id, message_id, read_at)
       SELECT $1 as user_id, m.id as message_id, $2 as read_at
       FROM messages m
       WHERE m.to_user_id = $1
         AND m.from_user_id = ANY($3)
         AND NOT EXISTS (
           SELECT 1 FROM message_reads mr
           WHERE mr.user_id = $1 AND mr.message_id = m.id
         )`,
      [currentUserId, now, partnerIds],
    );

    return res.status(200).json({ data: { updated: result.rowCount } });
  } catch (error) {
    next(error);
  }
});

// Fetch all conversations (unique users the current user has messaged)
router.get("/conversations", requireAuth, async (req, res, next) => {
  try {
    const currentUserId = req.auth!.id;

    const result = await query(
      `SELECT
         c.id AS conversation_id,
         c.context_type,
         c.property_id,
         CASE WHEN c.participant_one_id = $1
              THEN c.participant_two_id ELSE c.participant_one_id END AS user_id,
         u.name AS user_name,
         u.avatar AS user_avatar,
         p.title AS property_title,
         COALESCE(NULLIF(p.address, ''), NULLIF(p.town, ''),
                  NULLIF(p.city, ''), NULLIF(p.county, ''), '') AS property_location,
         p.price AS property_price,
         p.availability_status AS property_availability_status,
         p.image_url AS property_image_url,
         p.images AS property_images,
         EXISTS (
           SELECT 1 FROM presence_connections pc
            WHERE pc.user_id = u.id AND pc.expires_at > now()
         ) as user_online,
         u.last_seen_at,
         u.presence_revision,
         (SELECT m2.text
            FROM messages m2
           WHERE m2.conversation_id = c.id
           ORDER BY m2.created_at DESC
           LIMIT 1) as last_message,
         (SELECT m2.created_at
            FROM messages m2
           WHERE m2.conversation_id = c.id
           ORDER BY m2.created_at DESC
           LIMIT 1) as last_message_at,
        (SELECT m2.from_user_id
          FROM messages m2
          WHERE m2.conversation_id = c.id
          ORDER BY m2.created_at DESC
          LIMIT 1) as last_message_from_user_id,
         (
           SELECT COUNT(*)
           FROM messages m3
           WHERE m3.conversation_id = c.id
             AND m3.to_user_id = $1
             AND NOT EXISTS (
               SELECT 1
               FROM message_reads mr
               WHERE mr.user_id = $1
                 AND mr.message_id = m3.id
             )
         ) as unread_count
      FROM message_conversations c
      JOIN users u ON u.id = CASE WHEN c.participant_one_id = $1
              THEN c.participant_two_id ELSE c.participant_one_id END
      LEFT JOIN properties p
        ON p.id = c.property_id
       AND p.landlord_id IN (c.participant_one_id, c.participant_two_id)
      WHERE c.participant_one_id = $1 OR c.participant_two_id = $1
      ORDER BY last_message_at DESC NULLS LAST, c.created_at DESC`,
      [currentUserId],
    );

    return res.json({
      data: {
        conversations: result.rows,
      },
    });
  } catch (error) {
    next(error);
  }
});

router.delete("/conversation/:userId", requireAuth, async (req, res, next) => {
  try {
    const currentUserId = req.auth!.id;
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({ error: "userId is required." });
    }
    if (!UUID_PATTERN.test(userId)) {
      return res.status(400).json({ error: "Invalid userId." });
    }

    const result = await query(
      `DELETE FROM message_conversations
        WHERE participant_one_id = LEAST($1::uuid, $2::uuid)
          AND participant_two_id = GREATEST($1::uuid, $2::uuid)
          AND context_type = 'general'`,
      [currentUserId, userId],
    );

    return res.json({
      data: {
        deleted: result.rowCount ?? 0,
      },
    });
  } catch (error) {
    next(error);
  }
});

export default router;
