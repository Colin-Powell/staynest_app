import assert from 'node:assert/strict';
import test from 'node:test';
import { buildCampaignRecipientQuery, hasCampaignAdminRole, isApprovedCampaignImage, isEligibleCampaignAvailability, normalizeCampaignImageUrl, normalizeCampaignAudience, } from '../services/promotional_campaign_policy.js';
import { buildPromotionalCampaignMessage } from '../services/promotional_campaign_payload.js';
test('campaign administration accepts persisted admin aliases and rejects ordinary roles', () => {
    assert.equal(hasCampaignAdminRole({ role: 'admin' }), true);
    assert.equal(hasCampaignAdminRole({ role: 'tenant', roles: ['tenant', 'super_admin'] }), true);
    assert.equal(hasCampaignAdminRole({ role: 'landlord', roles: ['tenant', 'landlord'] }), false);
    assert.equal(hasCampaignAdminRole(undefined), false);
});
test('campaign audience accepts only the supported preference filters', () => {
    assert.deepEqual(normalizeCampaignAudience({ location: true, propertyType: false }), {
        location: true,
        propertyType: false,
    });
    assert.deepEqual(normalizeCampaignAudience({}), {
        location: false,
        propertyType: false,
    });
    assert.equal(normalizeCampaignAudience({ role: 'admin' }), null);
    assert.equal(normalizeCampaignAudience({ location: 'Nairobi' }), null);
});
test('campaign eligibility matches existing bookability rules', () => {
    for (const status of ['rented', 'fully_booked', 'maintenance', 'inactive', 'archived', 'expired', 'unknown', null]) {
        assert.equal(isEligibleCampaignAvailability(status), false);
    }
    assert.equal(isEligibleCampaignAvailability('available'), true);
    assert.equal(isEligibleCampaignAvailability('pending_booking'), true);
});
test('campaign recipient query requires opt-in and excludes non-tenant roles', () => {
    const { sql, params } = buildCampaignRecipientQuery({ city: 'Kilifi', category: 'Bedsitter' }, { location: true, propertyType: true });
    assert.deepEqual(params, ['kilifi', 'bedsitter']);
    assert.match(sql, /u\.settings->>'promotional_push' = 'true'/);
    assert.match(sql, /u\.settings->>'push_permission_granted' = 'true'/);
    assert.match(sql, /u\.is_suspended = false/);
    assert.match(sql, /u\.fcm_token IS NOT NULL/);
    assert.match(sql, /ARRAY\['landlord', 'host', 'admin', 'super_admin', 'administrator'\]/);
    assert.match(sql, /unnest\(coalesce\(tp\.preferred_cities/);
    assert.match(sql, /unnest\(coalesce\(tp\.preferred_categories/);
    assert.match(sql, /SELECT DISTINCT u\.id/);
});
test('missing preference filters do not become an all-location or all-type match', () => {
    const locationQuery = buildCampaignRecipientQuery({ city: 'Kilifi', category: 'Bedsitter' }, { location: true, propertyType: false });
    assert.match(locationQuery.sql, /EXISTS \(\s*SELECT 1 FROM tenant_profiles tp/);
    assert.match(locationQuery.sql, /preferred_cities/);
    assert.doesNotMatch(locationQuery.sql, /preferred_categories/);
});
test('campaign FCM payload includes only the approved image and exact property route data', () => {
    const message = buildPromotionalCampaignMessage({
        token: 'private-device-token',
        title: 'Find a home in Kilifi',
        body: 'Explore this approved listing.',
        imageUrl: 'https://res.cloudinary.com/staynest/image/upload/property.jpg',
        campaignId: '123e4567-e89b-42d3-a456-426614174001',
        propertyId: '123e4567-e89b-42d3-a456-426614174000',
    });
    assert.equal(message.notification.imageUrl, 'https://res.cloudinary.com/staynest/image/upload/property.jpg');
    assert.equal(message.android.notification.channelId, 'promotions');
    assert.deepEqual(message.data, {
        type: 'property_promotion',
        campaignId: '123e4567-e89b-42d3-a456-426614174001',
        propertyId: '123e4567-e89b-42d3-a456-426614174000',
        route: '/properties/123e4567-e89b-42d3-a456-426614174000',
        imageUrl: 'https://res.cloudinary.com/staynest/image/upload/property.jpg',
    });
    assert.equal(JSON.stringify(message.data).includes('private-device-token'), false);
});
test('campaign FCM payload falls back to text when a listing has no image', () => {
    const message = buildPromotionalCampaignMessage({
        token: 'private-device-token',
        title: 'Find a home in Kilifi',
        body: 'Explore this approved listing.',
        imageUrl: null,
        campaignId: '123e4567-e89b-42d3-a456-426614174001',
        propertyId: '123e4567-e89b-42d3-a456-426614174000',
    });
    assert.equal('imageUrl' in message.notification, false);
    assert.equal('imageUrl' in message.android.notification, false);
    assert.equal(message.data.imageUrl, '');
});
test('campaign property images normalize Cloudinary URLs and relative public IDs safely', () => {
    assert.equal(isApprovedCampaignImage('https://res.cloudinary.com/staynest/image/upload/v1/listing.jpg', 'staynest'), true);
    assert.equal(isApprovedCampaignImage('http://res.cloudinary.com/staynest/image/upload/listing.jpg', 'staynest'), true);
    assert.equal(normalizeCampaignImageUrl('staynest/listing', 'staynest'), 'https://res.cloudinary.com/staynest/image/upload/staynest/listing.jpg');
    assert.equal(isApprovedCampaignImage('https://example.test/listing.jpg', 'staynest'), false);
    assert.equal(isApprovedCampaignImage('https://res.cloudinary.com/other/image/upload/listing.jpg', 'staynest'), false);
});
//# sourceMappingURL=promotional_campaign_policy.test.js.map