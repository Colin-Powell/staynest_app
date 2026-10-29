import assert from 'node:assert/strict';
import test from 'node:test';
import { buildCampaignRecipientQuery, hasCampaignAdminRole, isApprovedCampaignImage, isEligibleCampaignAvailability, normalizeCampaignImageUrl, normalizeCampaignAudience, } from '../services/promotional_campaign_policy.js';
import { buildPromotionalCampaignData, buildPromotionalCampaignMessage, } from '../services/promotional_campaign_payload.js';
test('campaign administration accepts persisted admin aliases and rejects ordinary roles', () => {
    assert.equal(hasCampaignAdminRole({ role: 'admin' }), true);
    assert.equal(hasCampaignAdminRole({ role: 'tenant', roles: ['tenant', 'super_admin'] }), true);
    assert.equal(hasCampaignAdminRole({ role: 'landlord', roles: ['tenant', 'landlord'] }), false);
    assert.equal(hasCampaignAdminRole(undefined), false);
});
test('campaign audience accepts no additional targeting parameters', () => {
    assert.deepEqual(normalizeCampaignAudience({}), {});
    assert.equal(normalizeCampaignAudience({ location: true }), null);
    assert.equal(normalizeCampaignAudience({ propertyType: true }), null);
    assert.equal(normalizeCampaignAudience({ role: 'admin' }), null);
    assert.equal(normalizeCampaignAudience({ location: 'Nairobi' }), null);
});
test('campaign recipients include every account with a nonblank FCM token', () => {
    const { sql, params } = buildCampaignRecipientQuery();
    assert.deepEqual(params, []);
    assert.match(sql, /u\.fcm_token IS NOT NULL AND btrim\(u\.fcm_token\) <> ''/);
    assert.doesNotMatch(sql, /is_suspended|promotional_push|push_permission_granted|preferred_cities|preferred_categories|tenant/);
});
test('campaign audience rejects legacy location and property-type targeting filters', () => {
    assert.equal(normalizeCampaignAudience({ location: true, propertyType: false }), null);
});
test('campaign eligibility matches existing bookability rules', () => {
    for (const status of ['rented', 'fully_booked', 'maintenance', 'inactive', 'archived', 'expired', 'unknown', null]) {
        assert.equal(isEligibleCampaignAvailability(status), false);
    }
    assert.equal(isEligibleCampaignAvailability('available'), true);
    assert.equal(isEligibleCampaignAvailability('pending_booking'), true);
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
test('campaign notification-center data retains the property route and image', () => {
    assert.deepEqual(buildPromotionalCampaignData({
        campaignId: '123e4567-e89b-42d3-a456-426614174001',
        propertyId: '123e4567-e89b-42d3-a456-426614174000',
        imageUrl: 'https://res.cloudinary.com/staynest/image/upload/property.jpg',
    }), {
        type: 'property_promotion',
        campaignId: '123e4567-e89b-42d3-a456-426614174001',
        propertyId: '123e4567-e89b-42d3-a456-426614174000',
        route: '/properties/123e4567-e89b-42d3-a456-426614174000',
        imageUrl: 'https://res.cloudinary.com/staynest/image/upload/property.jpg',
    });
});
test('campaign property images normalize Cloudinary URLs and relative public IDs safely', () => {
    assert.equal(isApprovedCampaignImage('https://res.cloudinary.com/staynest/image/upload/v1/listing.jpg', 'staynest'), true);
    assert.equal(isApprovedCampaignImage('http://res.cloudinary.com/staynest/image/upload/listing.jpg', 'staynest'), true);
    assert.equal(normalizeCampaignImageUrl('staynest/listing', 'staynest'), 'https://res.cloudinary.com/staynest/image/upload/staynest/listing.jpg');
    assert.equal(isApprovedCampaignImage('https://example.test/listing.jpg', 'staynest'), false);
    assert.equal(isApprovedCampaignImage('https://res.cloudinary.com/other/image/upload/listing.jpg', 'staynest'), false);
});
//# sourceMappingURL=promotional_campaign_policy.test.js.map