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

/**
 * Checks whether a property is eligible for public booking.
 * 
 * Rules:
 * 1. Moderation status must be 'approved' (legacy status in properties table).
 * 2. Availability status must be bookable ('available', 'pending_booking', or unset/unknown default).
 * 3. Rented, unavailable, maintenance, and fully_booked statuses reject booking.
 */
export function isPropertyBookable(
  availabilityStatus: unknown,
  status: unknown,
): boolean {
  const normStatus = String(status ?? '').toLowerCase().trim();
  // Status must be approved for the property to be bookable
  if (normStatus !== '' && normStatus !== 'approved') {
    return false;
  }

  const availability = String(availabilityStatus ?? '').toLowerCase().trim();
  if (availability === '' || availability === 'unknown') {
    // If availability is unset, defaults to bookable if property is approved
    return normStatus === 'approved' || normStatus === '';
  }

  return bookableStatuses.has(availability);
}

/**
 * Returns a user-facing explanation if a property is not bookable.
 */
export function getPropertyIneligibilityReason(
  availabilityStatus: unknown,
  status: unknown,
): string | null {
  const normStatus = String(status ?? '').toLowerCase().trim();
  if (normStatus !== '' && normStatus !== 'approved') {
    return 'This property is currently unavailable and cannot accept new booking requests.';
  }

  const availability = String(availabilityStatus ?? '').toLowerCase().trim();
  if (availability === 'rented') {
    return 'This property has already been rented. Explore other available properties nearby.';
  }
  if (['unavailable', 'maintenance', 'fully_booked'].includes(availability)) {
    return 'This property is currently unavailable and cannot accept new booking requests.';
  }

  return null;
}
