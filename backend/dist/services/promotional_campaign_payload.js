export function buildPromotionalCampaignData(input) {
    return {
        type: 'property_promotion',
        campaignId: input.campaignId,
        propertyId: input.propertyId,
        route: `/properties/${input.propertyId}`,
        imageUrl: input.imageUrl ?? '',
    };
}
export function buildPromotionalCampaignMessage(input) {
    return {
        token: input.token,
        notification: {
            title: input.title,
            body: input.body,
            ...(input.imageUrl ? { imageUrl: input.imageUrl } : {}),
        },
        android: {
            priority: 'high',
            notification: {
                channelId: 'promotions',
                ...(input.imageUrl ? { imageUrl: input.imageUrl } : {}),
            },
        },
        data: buildPromotionalCampaignData(input),
    };
}
//# sourceMappingURL=promotional_campaign_payload.js.map