export interface PromotionalCampaignPayloadInput {
  token: string;
  title: string;
  body: string;
  imageUrl: string;
  campaignId: string;
  propertyId: string;
}

export function buildPromotionalCampaignMessage(input: PromotionalCampaignPayloadInput) {
  return {
    token: input.token,
    notification: {
      title: input.title,
      body: input.body,
      imageUrl: input.imageUrl,
    },
    android: {
      priority: 'high' as const,
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