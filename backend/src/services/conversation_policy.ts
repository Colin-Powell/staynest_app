export function orderConversationParticipants(
  first: string,
  second: string,
): [string, string] {
  return first.localeCompare(second) <= 0 ? [first, second] : [second, first];
}

export function isPropertyEligibleForMessaging(
  status: string | null | undefined,
): boolean {
  return status?.toLowerCase() === 'approved';
}