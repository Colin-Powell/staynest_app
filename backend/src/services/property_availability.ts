export const PROPERTY_AVAILABILITY_STATUSES = [
  'available',
  'pending_booking',
  'fully_booked',
  'unavailable',
  'rented',
  'maintenance',
] as const;

const availabilityStatuses = new Set<string>(PROPERTY_AVAILABILITY_STATUSES);
const bookableStatuses = new Set(['available', 'pending_booking']);

export function isPropertyAvailabilityStatus(
  value: unknown,
): value is (typeof PROPERTY_AVAILABILITY_STATUSES)[number] {
  return typeof value === 'string' && availabilityStatuses.has(value);
}

export function isPropertyBookable(
  availabilityStatus: unknown,
  legacyStatus: unknown,
): boolean {
  const availability = String(availabilityStatus ?? '').toLowerCase();
  const legacy = String(legacyStatus ?? '').toLowerCase();
  const effectiveStatus =
    availability === '' || availability === 'unknown' ? legacy : availability;
  return bookableStatuses.has(effectiveStatus);
}