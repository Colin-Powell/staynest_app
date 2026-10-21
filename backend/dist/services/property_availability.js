export const PROPERTY_AVAILABILITY_STATUSES = [
    'available',
    'pending_booking',
    'fully_booked',
    'unavailable',
    'rented',
    'maintenance',
];
const availabilityStatuses = new Set(PROPERTY_AVAILABILITY_STATUSES);
const bookableStatuses = new Set(['available', 'pending_booking']);
export function isPropertyAvailabilityStatus(value) {
    return typeof value === 'string' && availabilityStatuses.has(value);
}
export function isPropertyBookable(availabilityStatus, legacyStatus) {
    const availability = String(availabilityStatus ?? '').toLowerCase();
    const legacy = String(legacyStatus ?? '').toLowerCase();
    const effectiveStatus = availability === '' || availability === 'unknown' ? legacy : availability;
    return bookableStatuses.has(effectiveStatus);
}
//# sourceMappingURL=property_availability.js.map