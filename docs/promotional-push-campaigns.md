# Promotional Push Campaigns

## Architecture

Campaigns are separate from paid listing boosts in `promotion_campaigns`. The admin API persists a campaign and one delivery row per eligible user in PostgreSQL before it queues work in the existing BullMQ `notifications` queue. Firebase Admin sends batches of up to 500 device messages. The current token model is one FCM token per user; migration deduplicates legacy tokens and adds a partial unique index.

Campaign endpoints are mounted under `/api/admin/push-campaigns` and verify the user's current persisted administrator role for every request:

- `GET /properties?search=...` lists approved, available properties and marks whether the primary image is campaign-eligible.
- `POST /estimate` returns an informational recipient count using the same opt-in, role, token, location, and property-type filters used at submission.
- `GET /` and `GET /:id` provide campaign status and available metrics.
- `POST /` validates the property and image again, snapshots recipients and campaign data, records the idempotency key, commits the job, and then queues it for processing.

The campaign delivery status `submitted` means Firebase accepted the message submission. It is not a device delivery receipt. `opened_count` is recorded only when an authenticated recipient taps a campaign notification and the campaign/property pair matches their persisted delivery.

## Migration And Configuration

Apply the schema with the backend migration command before deploying code that uses the new routes:

```powershell
cd staynest_app/backend
npm run migrate
```

The backend uses the existing `DATABASE_URL`, `REDIS_URL`, and `FIREBASE_SERVICE_ACCOUNT` settings. `CLOUDINARY_URL` must identify the Cloudinary cloud used by listing images. Campaigns only accept HTTPS primary images hosted at that configured Cloudinary cloud; no administrator-supplied image URL is accepted. Firebase credentials remain server-side.

`npm start` runs migrations before starting the API. The development command does not apply schema automatically. Do not use campaign endpoints against production until the migration and release have been explicitly approved.

## Consent And Audience

Promotional consent is stored in `users.settings.promotional_push` and defaults to opted out unless the user explicitly enables it in Notification Settings. Global push-off also disables promotions. Token registration/refresh reports the OS notification authorization state into `users.settings.push_permission_granted`; campaign estimates and dispatch require it to be true. Legacy tokens remain ineligible until the updated app reports its permission state. The migration adds `users.is_suspended` (default false), which is checked during both audience estimation and dispatch. The client no longer subscribes to the legacy `promotions` topic for this campaign system. The backend excludes non-tenant roles, suspended users, users with push disabled, denied/unknown OS permission, missing/stale tokens, and users whose selected preference filter does not match. Preference filters use `tenant_profiles.preferred_cities` and `preferred_categories`; a missing value is not a match.

The database stores no raw token in campaign history. A delivery references its user and stores processing state, message ID, attempt count, sanitized error category, and open timestamp. Invalid/unregistered tokens are cleared from the existing user token field. Campaigns are manually sent only after the admin confirms; no listing or boost event triggers a campaign.

## Notification Behavior

The FCM notification and Android notification payloads include the validated listing image, and data includes only the campaign ID, property ID, image URL, type, and `/properties/{propertyId}` route. Android background/terminated notifications are handled by FCM using its image notification support and the dedicated `promotions` channel. Android foreground notifications use the existing local-notification plugin with Big Picture style; downloads require HTTPS Cloudinary URLs, reject redirects, allow only JPEG/PNG/WebP, and are limited to 5 MB and bounded timeouts. Text-only fallback is used when image loading fails. Temporary campaign images older than one day are removed on initialization.

Notification taps validate the property UUID and navigate through the existing property detail route. The route/API remains responsible for normal visibility and authentication rules. Invalid or removed listings therefore follow the existing property-detail fallback behavior.

This repository does not contain an iOS Notification Service Extension. iOS therefore uses the normal FCM text notification in background/terminated states; rich image attachments are not claimed as supported. To enable them, add and sign a Notification Service Extension in Xcode, configure the APNs `mutable-content` payload, and attach validated downloads using `UNNotificationServiceExtension`. Foreground promotions use the existing iOS system presentation and avoid an additional local notification.

## Tests

Backend policy and FCM payload tests run with `npm test` from `staynest_app/backend`. Flutter route-payload tests run with `flutter test test/promotion_notification_test.dart` from `staynest_app/frontend`. Tests use no production Firebase sends. Device/emulator verification is still required for Android expanded notifications and any future iOS extension.