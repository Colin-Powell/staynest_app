export function calculateGrowthPercent(
  current: number,
  previous: number,
): number {
  if (previous > 0) return ((current - previous) / previous) * 100;
  return current > 0 ? 100 : 0;
}

export function formatGrowthPercent(value: number): string {
  return `${value > 0 ? '+' : ''}${value.toFixed(1)}%`;
}

export function calculateRate(
  numerator: number,
  denominator: number,
): number | null {
  if (denominator <= 0 || numerator < 0) return null;
  return Number(((numerator / denominator) * 100).toFixed(1));
}

export function calculateOccupancyRate(
  bookedNights: number,
  propertyCount: number,
  periodDays: number,
): number {
  const capacity = propertyCount * periodDays;
  if (capacity <= 0) return 0;
  return Math.min(100, Math.max(0, (bookedNights / capacity) * 100));
}