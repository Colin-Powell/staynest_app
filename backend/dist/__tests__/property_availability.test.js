import assert from 'node:assert/strict';
import test from 'node:test';
import { isPropertyAvailabilityStatus, isPropertyBookable, } from '../services/property_availability.js';
test('only explicit available or pending-booking values are bookable', () => {
    assert.equal(isPropertyBookable('available', 'approved'), true);
    assert.equal(isPropertyBookable('pending_booking', 'approved'), true);
    assert.equal(isPropertyBookable('unknown', 'approved'), false);
    assert.equal(isPropertyBookable('fully_booked', 'approved'), false);
});
test('legacy availability values remain readable without treating approval as availability', () => {
    assert.equal(isPropertyBookable('unknown', 'available'), true);
    assert.equal(isPropertyBookable('unknown', 'approved'), false);
});
test('availability validation does not accept moderation states', () => {
    assert.equal(isPropertyAvailabilityStatus('available'), true);
    assert.equal(isPropertyAvailabilityStatus('pending_review'), false);
    assert.equal(isPropertyAvailabilityStatus('approved'), false);
});
//# sourceMappingURL=property_availability.test.js.map