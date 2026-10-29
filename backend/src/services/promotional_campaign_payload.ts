export interface PromotionalCampaignPayloadInput {
  token: string;
  title: string;
  body: string;
  imageUrl: string | null;
  campaignId: string;
  propertyId: string;
}

export function buildPromotionalCampaignData(input: Pick<PromotionalCampaignPayloadInput, 'campaignId' | 'propertyId' | 'imageUrl'>) {
  return {
    type: 'property_promotion',
    campaignId: input.campaignId,
    propertyId: input.propertyId,
    route: `/properties/${input.propertyId}`,
    imageUrl: input.imageUrl ?? '',
  };
}

export function buildPromotionalCampaignMessage(input: PromotionalCampaignPayloadInput) {
  return {
    token: input.token,
    notification: {
      title: input.title,
      body: input.body,
      ...(input.imageUrl ? { imageUrl: input.imageUrl } : {}),
    },
    android: {
      priority: 'high' as const,
      notification: {
        channelId: 'promotions',
        ...(input.imageUrl ? { imageUrl: input.imageUrl } : {}),
      },
    },
    data: buildPromotionalCampaignData(input),
  };
}