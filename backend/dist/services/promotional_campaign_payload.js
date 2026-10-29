export function buildPromotionalCampaignMessage(input) {
    return {
        token: input.token,
        notification: {
            title: input.title,
            body: input.body,
            imageUrl: input.imageUrl,
        },
        android: {
            priority: 'high',
            notification: {
                channelId: 'promotions',
                imageUrl: input.imageUrl,
            },
        },
        data: {
            type: 'property_promotion',
            campaignId: input.campaignId,
            propertyId: input.propertyId,
            route: `/properties/${input.propertyId}`,
            imageUrl: input.imageUrl,
        },
    };
}
//# sourceMappingURL=promotional_campaign_payload.js.map