export function calculatePlatformBookingFee(
  propertyPrice: number,
  feePercent: number,
): number {
  if (
    !Number.isFinite(propertyPrice) ||
    propertyPrice <= 0 ||
    !Number.isFinite(feePercent) ||
    feePercent < 0 ||
    feePercent > 100
  ) {
    throw new Error('The booking fee is invalid.');
  }
  return Math.round((propertyPrice * feePercent / 100 + Number.EPSILON) * 100) / 100;
}