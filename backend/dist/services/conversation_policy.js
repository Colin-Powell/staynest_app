export function orderConversationParticipants(first, second) {
    return first.localeCompare(second) <= 0 ? [first, second] : [second, first];
}
export function isPropertyEligibleForMessaging(status) {
    return status?.toLowerCase() === 'approved';
}
//# sourceMappingURL=conversation_policy.js.map