import assert from 'node:assert/strict';
import test from 'node:test';
import { getPreferenceCompletion, getProfileCompletion, reminderState, } from '../services/profile_completion.js';
test('preference progress counts only valid location, budget, and property type', () => {
    const completion = getPreferenceCompletion({
        preferred_cities: [' Kilifi '],
        budget_min: '5000',
        budget_max: '12000',
        preferred_categories: [],
    });
    assert.equal(completion.completionPercentage, 67);
    assert.deepEqual(completion.missingFields, ['propertyType']);
    assert.equal(completion.nextRecommendedField, 'propertyType');
});
test('invalid budgets and blank locations do not count as complete', () => {
    const completion = getPreferenceCompletion({
        preferred_cities: ['  '],
        budget_min: 12000,
        budget_max: 5000,
        preferred_categories: ['Bedsitter'],
    });
    assert.equal(completion.completedFields, 1);
    assert.deepEqual(completion.missingFields, ['preferredLocation', 'budgetRange']);
});
test('a budget with a missing bound is not complete', () => {
    const completion = getPreferenceCompletion({
        preferred_cities: [],
        budget_min: null,
        budget_max: 12000,
        preferred_categories: [],
    });
    assert.equal(completion.completedFields, 0);
    assert.equal(completion.missingFields[0], 'preferredLocation');
});
test('personal profile status is independent of preference completion', () => {
    assert.equal(getProfileCompletion('Amina').completionPercentage, 100);
    assert.equal(getProfileCompletion(' ').completionPercentage, 0);
    assert.equal(getPreferenceCompletion(null).completionPercentage, 0);
});
test('reminder snooze suppresses the reminder until its timestamp expires', () => {
    const preferences = getPreferenceCompletion(null);
    const now = new Date('2026-10-29T12:00:00.000Z');
    const snoozed = reminderState({
        onboardingReminder: { snoozedUntil: '2026-10-30T12:00:00.000Z' },
    }, preferences, now);
    const expired = reminderState({
        onboardingReminder: { snoozedUntil: '2026-10-28T12:00:00.000Z' },
    }, preferences, now);
    assert.equal(snoozed.shouldShowReminder, false);
    assert.equal(expired.shouldShowReminder, true);
});
test('a prominent reminder is limited to one per 24 hours', () => {
    const preferences = getPreferenceCompletion(null);
    const state = reminderState({
        onboardingReminder: { lastShownAt: '2026-10-29T11:00:00.000Z' },
    }, preferences, new Date('2026-10-29T12:00:00.000Z'));
    assert.equal(state.shouldShowReminder, false);
});
//# sourceMappingURL=profile_completion.test.js.map