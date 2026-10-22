# Property-Contextual Messaging

## Conversation policy

New property enquiries use one conversation per tenant, landlord, and property. Repeated initiation for the same property returns the existing conversation. A different property creates a different conversation, even when the participants are unchanged. Existing messages are backfilled into a separate general conversation per participant pair; their text, ordering, and read receipts are preserved.

The property association stores only the property ID. Conversation list and history responses join current property fields, so title, location, price, availability, and image are not copied into conversation records. Property context is returned only when the current property owner is a conversation participant.

Only authenticated tenants may initiate a property enquiry. The API resolves the landlord from the property row and accepts only approved listings. Starting a conversation does not create a booking or alter availability. Existing general conversations and the existing booking routes remain available.

## API contract

- `POST /api/messages/conversations/initiate` accepts `{ "property_id": "<uuid>" }` and returns the participant, `conversation_id`, `context_type`, and current property details.
- `GET /api/messages/conversations` returns one row per conversation, including `conversation_id` and current property details when applicable.
- `GET /api/messages/conversations/:conversationId/messages` returns authorized conversation metadata and paginated messages.
- `POST /api/messages` accepts `conversation_id` with the recipient and text. The server verifies membership and derives the recipient from the conversation.
- `POST /api/messages/mark-read` accepts `conversation_ids` for thread-specific receipts; `user_ids` remains supported for general/legacy callers.
- `DELETE /api/messages/conversations/:conversationId` deletes only the caller's selected conversation. The legacy pair endpoint targets only the general conversation.
- Socket.IO `message` events include `conversation_id` and current property context. Push data includes `conversationId`, `propertyId`, and `senderId`.

## Migration and deployment

`backend/scripts/add-message-conversations.sql` is additive and idempotent. The existing `npm run migrate` command applies it after `init-db.sql`. It creates nullable-property conversation rows, backfills each old participant pair to a general thread, links messages without changing message or read rows, adds foreign keys/indexes, and then makes the message thread reference required.

Deploy the backend migration and backend code before the Flutter release. Existing clients may continue using pair-based message requests; the server places those messages in the general thread. Do not run a database reset or delete/recreate existing messages.