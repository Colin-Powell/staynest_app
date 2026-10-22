import assert from 'node:assert/strict';
import test from 'node:test';
import { buildTrendingPropertiesQuery, NEW_LISTING_WINDOW_DAYS, TRENDING_EVENT_WEIGHTS, TRENDING_IMPRESSION_EVENT_TYPES, TRENDING_MIN_ENGAGEMENT_SCORE, TRENDING_MIN_EXPOSURES, TRENDING_MIN_UNIQUE_TENANTS, TRENDING_WINDOW_DAYS, } from '../services/discovery_rules.js';
import { DEFAULT_PUBLIC_PROPERTY_CATEGORY, normalizePublicPropertyCategory, publicPropertyCategorySql, } from '../services/property_category.js';
import { MAX_HOME_FEED_PROPERTIES_PER_LOCATION, MAX_HOME_FEED_LOCATION_SECTIONS, publicPropertyLocationSql, } from '../services/feed_location.js';
test('discovery windows and minimum Trending thresholds are centralized', () => {
    assert.equal(NEW_LISTING_WINDOW_DAYS, 30);
    assert.equal(TRENDING_WINDOW_DAYS, 7);
    assert.equal(TRENDING_MIN_UNIQUE_TENANTS, 3);
    assert.equal(TRENDING_MIN_EXPOSURES, 3);
    assert.equal(TRENDING_MIN_ENGAGEMENT_SCORE, 10);
});
test('Trending query deduplicates tenant events and normalizes by all supported impressions', () => {
    const sql = buildTrendingPropertiesQuery("COALESCE(p.status, 'pending_review') = 'approved'", 2);
    assert.match(sql, /DISTINCT ON \(ee\.property_id, ee\.user_id, ee\.event_type\)/);
    assert.match(sql, /COUNT\(DISTINCT user_id\)::int AS unique_tenants/);
    assert.match(sql, /COUNT\(\*\)::int AS exposure_count/);
    assert.match(sql, /actor\.roles @> ARRAY\['tenant'\]::text\[\]/);
    assert.match(sql, /ORDER BY rp\.engagement_rate DESC/);
    assert.deepEqual(TRENDING_IMPRESSION_EVENT_TYPES, ['property_impression']);
    assert.deepEqual(Object.keys(TRENDING_EVENT_WEIGHTS).sort(), [
        'property_save',
        'property_share',
        'property_view',
    ]);
    for (const eventType of TRENDING_IMPRESSION_EVENT_TYPES) {
        assert.ok(sql.includes(eventType));
    }
});
test('missing public property categories normalize to Apartment', () => {
    assert.equal(DEFAULT_PUBLIC_PROPERTY_CATEGORY, 'Apartment');
    assert.equal(normalizePublicPropertyCategory(null), 'Apartment');
    assert.equal(normalizePublicPropertyCategory('  '), 'Apartment');
    assert.equal(normalizePublicPropertyCategory('Studio'), 'Studio');
    assert.equal(publicPropertyCategorySql(), "COALESCE(NULLIF(BTRIM(p.category), ''), 'Apartment')");
});
test('home feed location rows use provided areas and stay capped at ten', () => {
    assert.equal(MAX_HOME_FEED_LOCATION_SECTIONS, 10);
    assert.equal(MAX_HOME_FEED_PROPERTIES_PER_LOCATION, 10);
    const locationSql = publicPropertyLocationSql();
    assert.ok(locationSql.indexOf('p.county') < locationSql.indexOf('p.town'));
    assert.ok(locationSql.includes('p.city'));
    assert.ok(locationSql.includes('p.neighborhood'));
});
//# sourceMappingURL=discovery_rules.test.js.map