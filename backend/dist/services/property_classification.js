export const PROPERTY_MANAGEMENT_TYPES = [
    'landlord',
    'agent',
    'staynest',
    'unspecified',
];
export const PROPERTY_VIEWING_FEE_TYPES = [
    'free',
    'paid',
    'unspecified',
];
export const PROPERTY_VIEWING_FEE_COLLECTORS = [
    'landlord',
    'agent',
];
export function validatePropertyClassification(input, requireExplicitViewingFee = false) {
    const managementType = String(input.managementType ?? '').toLowerCase();
    const feeType = String(input.viewingFeeType ?? '').toLowerCase();
    const assignedAgentId = String(input.assignedAgentId ?? '').trim();
    const assignedManagerId = String(input.assignedManagerId ?? '').trim();
    const collector = String(input.viewingFeeCollector ?? '').toLowerCase();
    const amountValue = input.viewingFeeAmount;
    const amount = amountValue == null || amountValue === '' ? null : Number(amountValue);
    if (!PROPERTY_MANAGEMENT_TYPES.includes(managementType)) {
        return 'Invalid property management type.';
    }
    if (managementType === 'agent' && (!assignedAgentId || assignedManagerId)) {
        return 'Agent-managed properties must have only an assigned agent.';
    }
    if (managementType === 'staynest' && (!assignedManagerId || assignedAgentId)) {
        return 'StayNest-managed properties must have only an assigned administrator.';
    }
    if (!['agent', 'staynest'].includes(managementType) &&
        (assignedAgentId || assignedManagerId)) {
        return 'Assigned managers must match the property management type.';
    }
    if (!PROPERTY_VIEWING_FEE_TYPES.includes(feeType)) {
        return 'Choose whether viewing is free or requires a fee.';
    }
    if (requireExplicitViewingFee && feeType === 'unspecified') {
        return 'Choose free viewing or a required viewing fee before publishing.';
    }
    if (feeType === 'paid') {
        if (amount == null || !Number.isFinite(amount) || amount <= 0) {
            return 'A paid viewing fee must be a positive amount.';
        }
        const expectedCollector = managementType === 'staynest'
            ? 'landlord'
            : managementType;
        if (collector !== expectedCollector) {
            return 'Viewing fee collector must match the property manager.';
        }
        return null;
    }
    if (amount != null && (!Number.isFinite(amount) || amount !== 0)) {
        return 'Free or unspecified viewing must not have a fee amount.';
    }
    if (collector) {
        return 'Free or unspecified viewing must not have a fee collector.';
    }
    return null;
}
//# sourceMappingURL=property_classification.js.map