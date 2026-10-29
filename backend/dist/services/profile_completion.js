export const PREFERENCE_FIELDS = [
    'preferredLocation',
    'budgetRange',
    'propertyType',
];
export const SUPPORTED_PROPERTY_TYPES = new Set([
    'apartment', 'apartments', 'bedsitter', 'single room', 'one bedroom',
    'shared room', 'hostel', 'studio',
]);
function nonEmptyStringList(value) {
    if (!Array.isArray(value))
        return [];
    return value
        .filter((item) => typeof item === 'string')
        .map((item) => item.trim())
        .filter((item) => item.length > 0 && item.length <= 100);
}
function validBudget(profile) {
    if (profile.budget_min == null || profile.budget_max == null ||
        String(profile.budget_min).trim() === '' ||
        String(profile.budget_max).trim() === '')
        return false;
    const minimum = Number(profile.budget_min);
    const maximum = Number(profile.budget_max);
    return Number.isFinite(minimum) && Number.isFinite(maximum) &&
        minimum >= 0 && maximum >= minimum && maximum > 0;
}
export function getPreferenceCompletion(profile) {
    const completedFields = [];
    if (profile) {
        if (nonEmptyStringList(profile.preferred_cities).length > 0) {
            completedFields.push('preferredLocation');
        }
        if (validBudget(profile))
            completedFields.push('budgetRange');
        if (nonEmptyStringList(profile.preferred_categories).some((category) => SUPPORTED_PROPERTY_TYPES.has(category.toLowerCase()))) {
            completedFields.push('propertyType');
        }
    }
    const missingFields = PREFERENCE_FIELDS.filter((field) => !completedFields.includes(field));
    return {
        completionPercentage: Math.round((completedFields.length / PREFERENCE_FIELDS.length) * 100),
        completedFields: completedFields.length,
        totalFields: PREFERENCE_FIELDS.length,
        missingFields,
        nextRecommendedField: missingFields[0] ?? null,
    };
}
export function getProfileCompletion(name) {
    const complete = typeof name === 'string' && name.trim().length > 0;
    return {
        completionPercentage: complete ? 100 : 0,
        completedFields: complete ? 1 : 0,
        totalFields: 1,
        missingFields: complete ? [] : ['name'],
        nextRecommendedField: complete ? null : 'name',
    };
}
export function isPreferenceField(value) {
    return typeof value === 'string' &&
        PREFERENCE_FIELDS.includes(value);
}
export function reminderState(settings, preferences, now = new Date()) {
    const root = settings && typeof settings === 'object'
        ? settings
        : {};
    const reminder = root.onboardingReminder && typeof root.onboardingReminder === 'object'
        ? root.onboardingReminder
        : {};
    const snoozedUntil = typeof reminder.snoozedUntil === 'string'
        ? reminder.snoozedUntil
        : null;
    const snoozed = snoozedUntil !== null && Date.parse(snoozedUntil) > now.getTime();
    const lastShownAt = typeof reminder.lastShownAt === 'string'
        ? reminder.lastShownAt
        : null;
    const shownRecently = lastShownAt !== null &&
        now.getTime() - Date.parse(lastShownAt) < 24 * 60 * 60 * 1000;
    return {
        shouldShowReminder: preferences.missingFields.length > 0 && !snoozed && !shownRecently,
        reminderField: preferences.nextRecommendedField,
        snoozedUntil: snoozed ? snoozedUntil : null,
        lastShownAt,
    };
}
//# sourceMappingURL=profile_completion.js.map