export function calculateGrowthPercent(current, previous) {
    if (previous > 0)
        return ((current - previous) / previous) * 100;
    return current > 0 ? 100 : 0;
}
export function formatGrowthPercent(value) {
    return `${value > 0 ? '+' : ''}${value.toFixed(1)}%`;
}
export function calculateRate(numerator, denominator) {
    if (denominator <= 0 || numerator < 0)
        return null;
    return Number(((numerator / denominator) * 100).toFixed(1));
}
export function calculateOccupancyRate(bookedNights, propertyCount, periodDays) {
    const capacity = propertyCount * periodDays;
    if (capacity <= 0)
        return 0;
    return Math.min(100, Math.max(0, (bookedNights / capacity) * 100));
}
//# sourceMappingURL=landlord_metrics.js.map