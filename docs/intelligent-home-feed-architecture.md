# StayNest Intelligent Home Feed Architecture

Status: Read-only assessment and implementation plan

Date: 2026-09-22

This document is based on the current repository implementation. It is intentionally a planning deliverable: it does not change the Home Feed, API behavior, database schema, or ranking logic.

## 1. Existing Architecture

### Flutter application

The user-facing Home Feed starts at [frontend/lib/screens/home/home_view.dart](../frontend/lib/screens/home/home_view.dart). `HomeView` is a `StatefulWidget` that owns loading, error, category selection, and the map of rendered collections.

Current load sequence in `_loadCollections()`:

1. Fetch `/properties/categories` through `PropertiesApi.getCategories()`.
2. For authenticated users, fetch `/properties/me/recently-viewed`.
3. For authenticated users, fetch `/properties/recommendations`.
4. If categories are empty, fetch `/properties` and build three client-side fallback collections.
5. Map every row with `mapApiProperty()` and render collections as horizontal property-card lists.

The screen applies category filtering locally with `categoryMatchesUiFilter()`. It has a single global loading/error state, a pull-to-refresh action, and no feed cursor or section-level retry state. `PropertyCard` owns favorite interaction and delegates selection back to the application shell.

Relevant frontend surfaces:

| Concern | Current implementation | Assessment |
|---|---|---|
| Home orchestration | `HomeView._loadCollections()` | Business orchestration is in the widget. |
| API client | [frontend/lib/services/properties_api.dart](../frontend/lib/services/properties_api.dart) and `ApiClient` | Existing wrapper can support a feed endpoint. |
| General repository | [frontend/lib/repository/remote_database_repository.dart](../frontend/lib/repository/remote_database_repository.dart) | Existing property loading and caching are used outside Home. |
| Property mapping | [frontend/lib/utils/property_mapper.dart](../frontend/lib/utils/property_mapper.dart) | Normalizes legacy and current property response fields. |
| Property model | [frontend/lib/models/property.dart](../frontend/lib/models/property.dart) | Covers display fields, but not feed metadata or structured taxonomy. |
| State management | Local `StatefulWidget` state | No dedicated Home Feed controller/provider exists. Preserve the existing app pattern until its state-management boundary is confirmed elsewhere. |
| Caching | [frontend/lib/screens/home/cache_engine.dart](../frontend/lib/screens/home/cache_engine.dart) | Hive plus memory cache, request deduplication, stale-while-revalidate. `getOrFetch()` does not notify the screen when background refresh completes. |
| Images | `CachedNetworkImage` in `PropertyCard` | Reusable and appropriate for feed cards. |
| Favorites | `AppSession.savedPropertyIds` plus `RemoteDatabaseRepository` | Existing optimistic save flow; not currently a ranking input on Home. |
| Search | [frontend/lib/screens/home/search_view.dart](../frontend/lib/screens/home/search_view.dart) | Most filtering is client-side over the fetched result set. |
| Location | `PropertyService.fetchNearby()`, map/location screens, and geocoding helpers | Nearby capability exists, but Home does not provide a location context to its requests. |
| Recent views | `PropertiesApi.recordPropertyView()` and `/properties/me/recently-viewed` | Existing signal, currently only displayed as a separate collection. |
| Bookings | `BookingService` and booking screens | Booking history is not supplied to Home ranking. |
| Analytics | Firebase plus `/analytics/track` | Property events exist, but Home impressions and consistent source-section attribution are incomplete. |

### Backend application

Backend startup mounts `/api/properties` in [backend/src/app.ts](../backend/src/app.ts). The main property route is [backend/src/routes/properties.ts](../backend/src/routes/properties.ts).

Existing public discovery routes:

| Route | Current behavior | Limitation for intelligent feed |
|---|---|---|
| `GET /api/properties` | Approved listings, optional category/city/landlord/coordinates/history, feed-score ordering, hard limit 50 | No real `page`, `limit`, cursor, section, or user-context contract. |
| `GET /api/properties/categories` | Groups approved listings by exact category and orders by feed score | Entire groups are returned; no per-section limit, metadata, diversity, or pagination. |
| `GET /api/properties/recommendations` | Uses tenant profile fields, optional coordinates/history, and a short Redis cache | Returns only a property list; recommendation inputs and explanation are not represented as a feed. |
| `GET /api/properties/nearby` | Radius/category query, geographic ordering, up to 50 rows | Useful candidate source, not a composed feed section. |
| `GET /api/properties/me/recently-viewed` | Authenticated latest recently viewed properties | Fixed small list; not related-item discovery. |

The current feed score combines engagement, velocity, active promotion boost, capped freshness, and rating. It is a useful baseline, but it is not user-specific and does not currently apply diversity, seen-item suppression, explicit availability, favorites, or booking history.

### Database

The current foundation is in [backend/scripts/init-db.sql](../backend/scripts/init-db.sql). Existing relevant tables are:

- `properties`: title, description, category, price, images, amenities, coordinates, administrative location, rating/review counters, landlord, and status.
- `tenant_profiles`: budget, preferred categories/cities, consent, and personalization opt-in.
- `favorites`: user-to-property saves.
- `bookings` and `property_availability`: booking state and date blocks.
- `engagement_events`: user/session property events with metadata and duration.
- `property_analytics`: aggregate impressions, views, saves, bookings, engagement score, and velocity score.
- `user_engagement_profiles`: coarse user activity profile and browsing patterns.
- `search_events`: search demand and behavior history.
- `recently_viewed`: recent user-property history.
- `promotion_campaigns`, `reviews`, and `verifications`: promotion, trust, and quality-related sources.

The schema already has coordinates and a location taxonomy route, but it does not yet have a normalized property taxonomy, campus relationship model, explicit availability summary, listing verification fields, or spatial indexing strategy.

## 2. Gap Analysis

| Existing capability | Missing capability | Required change | Risk |
|---|---|---|---|
| Category, recommendations, nearby, and recent-view routes | One feed contract with dynamic sections | Add a versioned feed service and endpoint while retaining existing routes | Medium: response and cache compatibility |
| Flat `Property` model | Section metadata, source, cursor, distance, recommendation context | Add feed-only DTOs; keep `Property` compatible initially | Medium: mapper changes |
| Feed score and velocity score | Transparent user-aware ranking and configurable weights | Introduce candidate/ranker/composer modules with deterministic scoring | High: ranking regressions and paid-promotion fairness |
| Coordinates on `properties` | Efficient radius/campus querying | Validate coordinate quality, add spatial representation/index, migrate incrementally | Medium: migration and query-plan risk |
| Free-text `category` | Extensible taxonomy and room/property type distinction | Add taxonomy tables/IDs and backfill current categories | High: category compatibility and data cleanup |
| `tenant_profiles` preferences | Campus, neighborhood, budget evidence, consented behavior profile | Extend profile/context data and define retention rules | High: privacy and consent requirements |
| Engagement event table | Consistent event vocabulary and feed/source attribution | Version analytics events and validate metadata server-side | Medium: event volume and abuse |
| Favorites and bookings | Ranking inputs and availability-aware filtering | Use server-side aggregates and eligible booking states | High: exposure/privacy mistakes if joins are wrong |
| Hive stale cache | Feed cache keyed by user/context and refresh notification | Add feed cache keys, schema version, and explicit stale state | Medium: personalized data leakage if keying is incomplete |
| Single Home loading flag | Independent section loading/error/pagination | Move orchestration into feed state/repository | Medium: UI state migration |
| `/properties` accepts coordinates | No actual pagination despite client parameters | Add cursor pagination to the new feed first; separately repair legacy pagination | Medium: callers currently assume list responses |

## 3. Proposed Architecture

```text
Flutter HomeView
  -> HomeFeedController / FeedState
    -> FeedRepository
      -> FeedApiClient
        -> GET /api/home/feed
          -> FeedService
            -> Context Resolver
            -> Candidate Generators
            -> Eligibility Filters
            -> Deterministic Ranker
            -> Diversity and Deduplication
            -> Section Composer
              -> PostgreSQL / Redis / analytics aggregates
```

The first implementation should be a modular monolith inside the existing backend. Candidate generation and ranking remain server-side. Flutter receives renderable sections and never computes recommendation scores or distances.

### Feed response shape

The proposed endpoint is additive and versioned:

```json
{
  "data": {
    "schemaVersion": 1,
    "generatedAt": "2026-09-22T10:00:00Z",
    "context": {
      "source": "device|campus|town|saved_preference|none",
      "campusId": "optional",
      "neighborhood": "optional",
      "radiusKm": 5
    },
    "sections": [
      {
        "id": "nearby_bedsitters",
        "type": "property_carousel",
        "title": "Bedsitters Near You",
        "subtitle": "Relevant available places nearby",
        "algorithm": "nearby_personalized_v1",
        "items": [],
        "nextCursor": null,
        "hasMore": false
      }
    ],
    "nextCursor": "optional-feed-cursor"
  }
}
```

Section types are a backend-controlled enum with a Flutter renderer registry. The initial client should support `property_carousel`, `property_grid`, and `property_list`; unknown types must be ignored rather than crashing the feed.

Existing `/properties/categories`, `/properties/recommendations`, `/properties/nearby`, and `/properties/me/recently-viewed` remain available during migration. Their consumers can move to the new feed one surface at a time.

## 4. Database Changes

Schema changes should be additive migrations, not edits that assume a clean database. Each migration must include backfill counts, null-rate checks, and rollback notes.

### Properties and taxonomy

| Name | Type | Purpose | Nullable/default | Index/relationship | Migration implication |
|---|---|---|---|---|---|
| `property_types` | table: `id`, `slug`, `label`, `parent_id`, `active` | Extensible property taxonomy | `active` defaults true; `parent_id` nullable | Unique `slug`; self-reference for hierarchy | Seed mappings from current `properties.category`. |
| `room_types` | table: `id`, `slug`, `label`, `active` | Distinguish bedsitter/single/shared/etc. from building type | Nullable relation initially | Unique `slug` | Backfill only where current data is unambiguous. |
| `properties.property_type_id` | uuid FK | Canonical property type | Nullable during migration | FK plus lookup index | Keep `category` until all writers/readers migrate. |
| `properties.room_type_id` | uuid FK | Canonical room type | Nullable | FK plus lookup index | Do not infer uncertain values from titles. |
| `properties.verification_status` | text | Listing/property trust eligibility | Default `pending` | Partial index for eligible public listings | Derive initial value from current status/verification data. |
| `properties.availability_status` | text | Fast eligibility filter | Default `unknown` | Partial index for available listings | Reconcile with booking/availability records. |
| `properties.updated_at` | timestamptz | Freshness and cache invalidation | Default `now()` | `(status, updated_at DESC)` where useful | Add update trigger or update all write paths. |
| `properties.location_accuracy_m` | numeric | Quality of coordinates | Nullable | No index initially | Populate only when source accuracy is known. |
| `properties.campus_id` | uuid FK | Direct campus association where validated | Nullable | `(campus_id, status)` | Do not hard-code campus neighborhoods in Flutter. |

### Location taxonomy

Add `campuses`, `locations`, and `campus_locations` only if the existing location route cannot represent these relationships. `campus_locations` should carry relationship type and optional distance/radius metadata rather than embedding neighborhood lists in application code. A geospatial extension or generated geohash column should be selected after checking the production PostgreSQL capabilities.

### Behavior and ranking support

| Name | Type | Purpose | Index requirement | Cost/control |
|---|---|---|---|---|
| `engagement_events.source_section` | text nullable | Attribute an event to feed section | Included in event reporting index only if queried frequently | Small row cost; validate length and enum. |
| `engagement_events.location_context` | jsonb nullable | Store coarse consented context, never precise location by default | No standalone index initially | Apply retention and redaction rules. |
| `user_discovery_profiles` | table keyed by user | Materialized preference signals from searches/views/saves | `user_id` primary key, `updated_at` | Rebuildable derived data; do not make it the source of truth. |
| `feed_impressions` | optional batch table | Efficient section/item impression ingestion | `(session_id, created_at)` and `(listing_id, created_at)` if added | Prefer batched events and retention limits. |

### Required indexes and rationale

1. A spatial index or geohash index on eligible property coordinates supports radius and campus candidate generation. Validate with `EXPLAIN ANALYZE`; do not add both a geospatial and geohash index without a measured query need.
2. A partial index on `(status, availability_status, updated_at DESC)` supports eligible fresh-listing candidates and avoids scanning hidden listings.
3. A partial or composite index on `(campus_id, property_type_id, status)` supports campus/category sections.
4. Existing event indexes support user/property event lookup, but time-window queries may need a composite `(event_type, created_at DESC)` index after measuring analytics workloads.
5. Existing favorites and booking indexes are adequate for primary joins; add ranking-specific indexes only after query plans show a bottleneck.

## 5. API Changes

### Proposed endpoint

`GET /api/home/feed`

Authentication is optional. An authenticated request may use consented profile and behavior data. An anonymous request uses cold-start context only.

Request parameters:

- `lat`, `lng`: accepted only when valid and permission has been granted; server validates bounds and precision.
- `campusId`, `locationId`: explicit user-selected context.
- `radiusKm`: bounded allow-list/default, not an arbitrary expensive radius.
- `cursor`: opaque signed continuation token.
- `limit`: bounded server-side.
- `sessionId`: client-generated non-sensitive session identifier.
- `refresh`: optional client hint; never bypasses authorization or rate limits.

The server resolves context in this order: explicit selected location, permitted device location, saved campus/location preference, recent consented search context, then no location. Location is never required for a successful response.

### Pagination and errors

The endpoint returns section-level `nextCursor` values and an optional feed cursor. The cursor contains a version, stable ranking boundary, context hash, and expiry; clients cannot edit its ranking inputs. A section with no candidates is omitted. A failed optional section returns a section error state only if the product needs a retry affordance; the main response remains usable.

Use stable IDs and `generatedAt` for caching. Personalized responses must include user identity and a normalized context hash in private cache keys. Public responses must never be served from a cache that can contain user-specific ordering.

Rate-limit feed generation and event ingestion independently. Validate property visibility, status, landlord blocks, reports, and availability on the server.

### Compatibility

The initial Flutter repository should support both the current list APIs and the new feed response behind a feature flag. The old Home path remains the fallback until feed parsing, rendering, analytics, and error behavior are proven.

## 6. Recommendation Logic

### Candidate sources

1. Nearby eligible listings from spatial/campus context.
2. Explicit category, room type, price, amenity, and location preferences.
3. Recent searches and applied filters.
4. Favorites and recently viewed related listings.
5. Fresh eligible listings.
6. Trending listings using recent engagement velocity, not lifetime views alone.
7. Verified/high-quality listings for cold start.

Candidate generation must use bounded database queries and return only IDs plus the fields required for ranking. It must not fetch the full inventory into Flutter.

### Eligibility filters

Filter before ranking:

- public/approved listing status;
- available or explicitly eligible availability state;
- non-deleted and non-blocked landlord/property;
- valid listing ownership relationships;
- permission-safe location context;
- price/category/filter constraints selected by the user.

### Deterministic v1 score

Use a normalized score with weights stored in configuration, not literals scattered through routes:

```text
score =
  w_preference * preferenceScore
  + w_location * locationScore
  + w_freshness * freshnessScore
  + w_engagement * recentEngagementScore
  + w_quality * qualityScore
  + w_availability * availabilityScore
  + w_promotion * eligiblePromotionScore
  - w_negative * negativeSignalScore
```

Weights must be versioned and logged internally with the feed generation. Freshness and velocity decay over time. Promotion can boost eligible listings but must not bypass visibility, trust, availability, diversity, or explicit user filters.

### Cold start and fallback

For a new or anonymous user:

1. Explicit campus/location and filters.
2. Nearby eligible inventory.
3. Fresh inventory.
4. Recent relevant engagement.
5. Popular relevant inventory.
6. Verified/high-quality inventory.

With no location, use selected campus/town/neighborhood, then global eligible inventory. With no behavior, do not fabricate personal preference scores.

### Diversity and repetition controls

After ranking, apply:

- global listing-ID deduplication;
- section-level deduplication;
- recently viewed suppression where it improves discovery, while retaining a dedicated Continue Exploring section;
- caps per landlord and neighborhood;
- category/type diversity;
- stable tie-breaking by listing ID.

The composer omits empty sections, merges very small compatible sections where appropriate, and limits the number of sections returned on the first page.

### Internal explainability

Store or log a short-lived internal recommendation record containing feed ID, listing ID, algorithm version, score, and normalized signal values. Do not expose raw private behavior or internal weights in the public response.

## 7. Flutter Changes

### New client boundaries

Add feed-only models, keeping the existing `Property` mapper compatible:

- `HomeFeedResponse`
- `FeedContext`
- `FeedSection`
- `FeedSectionState`
- `FeedCursor`
- `FeedItem`

Add a `FeedRepository` above `PropertiesApi` and a `HomeFeedController` or equivalent state holder using the existing project state-management convention. `HomeView` should become a renderer and event-forwarder, not the owner of recommendation calls.

### Rendering and state

The controller should expose:

- initial loading with header/category skeletons;
- loaded sections with independent section states;
- stale cached feed plus refreshing indicator;
- per-section retry;
- pull-to-refresh with request cancellation or generation guards;
- pagination per section/feed cursor;
- empty and low-inventory states;
- location denied/unavailable context without blocking the feed;
- unknown section-type ignore behavior.

Each property impression should include feed ID, section ID, listing ID, position, and algorithm version. Detail, favorite, share, contact, map, and booking events should preserve the source section when available.

Cache keys must include schema version, authenticated user identity when applicable, context hash, and feed parameters. Do not reuse the current global `props_categories` key for a personalized feed.

### Backward compatibility

Keep the existing category pill behavior initially by translating the selected category into a feed request/filter. Do not filter a personalized response only by display text if the backend has already composed sections; ask the backend for the category context or define a clear client-visible filter contract.

## 8. Migration Plan

### Phase 1 - Data foundation

Audit and normalize listing fields, taxonomy, status, verification, availability, timestamps, and coordinate quality. Add additive migrations and backfill reports. No Home behavior change.

### Phase 2 - Location infrastructure

Validate location permission states in Flutter, add campus/location relationships in the backend, and implement measured spatial candidate queries. Preserve `/properties/nearby`.

### Phase 3 - Feed service and contract

Implement `FeedService`, candidate source interfaces, eligibility filtering, section DTOs, opaque cursors, and `/home/feed`. Start with public/cold-start sections and feature-flag the endpoint.

### Phase 4 - Basic ranking

Move the existing feed score into a versioned ranker, add location/freshness/availability signals, and emit internal score diagnostics. Keep promotion and visibility rules explicit.

### Phase 5 - Dynamic sections

Add nearby, new, trending, type-nearby, budget, and recently viewed sections through the composer. Add diversity and global deduplication.

### Phase 6 - Behavior tracking

Standardize event names and metadata, add source-section attribution, batch impressions, and enforce server validation/rate limits.

### Phase 7 - Personalization

Use consented favorites, views, searches, filters, booking outcomes, and tenant profile preferences. Add cold-start fallback tests and privacy retention enforcement.

### Phase 8 - Flutter migration

Add feed models/repository/controller, section renderers, cache keys, section-level errors, pagination, and feature-flagged rollout. Compare old and new feed health before removing old Home calls.

### Phase 9 - Analytics and optimization

Measure conversion and latency by section and algorithm version. Tune weights, indexes, cache TTLs, and candidate limits from observed query plans and product metrics. Only then consider learning-to-rank or ML experimentation.

## 9. Testing Strategy

### Unit tests

- distance normalization and radius boundaries;
- eligibility filters for hidden, deleted, blocked, unavailable, and unverified listings;
- freshness and velocity decay;
- deterministic score calculation and weight versions;
- cold-start context resolution;
- section composition, omission, merging, and limits;
- global/section deduplication and landlord/neighborhood diversity;
- cursor encoding, expiry, and context mismatch rejection;
- feed DTO parsing with unknown section types.

### Backend integration tests

- anonymous and authenticated feed requests;
- location granted, denied, unavailable, and explicit campus fallback;
- authorization and cache isolation between users;
- pagination stability and repeated-cursor behavior;
- hidden/deleted/blocked listing exclusion;
- availability and booking-state filtering;
- event validation, rate limiting, duplicate impressions, and retention;
- old property endpoints remain response-compatible;
- query plans for radius, campus, category, freshness, and event windows.

### Flutter tests

- feed parsing and legacy property mapping;
- initial, stale, refreshing, empty, and total failure states;
- independent section loading/error/retry;
- unknown section type handling;
- pull-to-refresh and pagination generation guards;
- location permission denied/unavailable fallback;
- source-section analytics payloads;
- offline cached feed behavior;
- property selection and favorite behavior remain intact.

### Manual scenarios

Test a new user, returning user, authenticated and anonymous sessions, location enabled/denied/unavailable, selected campus, no nearby inventory, low inventory, many nearby listings, stale listings, unverified listings, blocked landlords, repeated views, multiple properties from one landlord, slow network, API failure in one section, offline mode, and property creation/update/delete while a feed is cached.

## Decision Summary

The repository already contains enough infrastructure to begin with a deterministic server-side feed: approved property queries, coordinate fields, tenant preferences, engagement aggregates, recent views, favorites, bookings, location routes, Redis caching, and Flutter stale caching. The principal architectural change is to put those inputs behind a dedicated feed service and structured section contract, then move Home orchestration out of `HomeView` without removing the existing APIs.

The first implementation approval should cover only Phases 1-3 and the feature-flagged contract. Ranking personalization, schema expansion, and client migration should follow evidence from data quality, query plans, and compatibility tests.