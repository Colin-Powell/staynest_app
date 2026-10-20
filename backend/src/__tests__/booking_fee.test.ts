import assert from 'node:assert/strict';
import test from 'node:test';
import { calculatePlatformBookingFee } from '../services/booking_fee.js';

test('calculates the configured percentage from monthly property rent', () => {
  assert.equal(calculatePlatformBookingFee(4000, 10), 400);
});

test('allows a zero-percent platform fee', () => {
  assert.equal(calculatePlatformBookingFee(4000, 0), 0);
});

test('rounds the fee to two decimal places', () => {
  assert.equal(calculatePlatformBookingFee(1234.56, 5), 61.73);
});

test('rejects invalid prices and fee percentages', () => {
  assert.throws(() => calculatePlatformBookingFee(0, 10), /booking fee is invalid/);
  assert.throws(() => calculatePlatformBookingFee(4000, -1), /booking fee is invalid/);
  assert.throws(() => calculatePlatformBookingFee(4000, 101), /booking fee is invalid/);
});