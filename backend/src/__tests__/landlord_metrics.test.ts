import assert from 'node:assert/strict';
import test from 'node:test';
import {
  calculateRate,
  calculateGrowthPercent,
  calculateOccupancyRate,
  formatGrowthPercent,
} from '../services/landlord_metrics.js';
import { LANDLORD_RECOMMENDATION_THRESHOLDS } from '../services/landlord_recommendations.js';

test('rates report unavailable denominators without fabricated percentages', () => {
  assert.equal(calculateRate(0, 0), null);
  assert.equal(calculateRate(2, 0), null);
  assert.equal(calculateRate(3, 10), 30);
});

test('booking and occupancy growth handle empty and populated periods', () => {
  assert.equal(calculateGrowthPercent(0, 0), 0);
  assert.equal(calculateGrowthPercent(3, 0), 100);
  assert.equal(calculateGrowthPercent(3, 2), 50);
  assert.equal(calculateGrowthPercent(1, 2), -50);
  assert.equal(formatGrowthPercent(0), '0.0%');
  assert.equal(formatGrowthPercent(12.34), '+12.3%');
  assert.equal(formatGrowthPercent(-12.34), '-12.3%');
});

test('occupancy divides booked nights by portfolio capacity and caps at 100%', () => {
  assert.equal(calculateOccupancyRate(14, 2, 7), 100);
  assert.equal(calculateOccupancyRate(7, 2, 7), 50);
  assert.equal(calculateOccupancyRate(30, 1, 7), 100);
  assert.equal(calculateOccupancyRate(4, 0, 7), 0);
});

test('landlord recommendation rules expose conservative sample thresholds', () => {
  assert.equal(LANDLORD_RECOMMENDATION_THRESHOLDS.unansweredHours, 12);
  assert.equal(LANDLORD_RECOMMENDATION_THRESHOLDS.lowConversionMinimumViews, 30);
  assert.equal(LANDLORD_RECOMMENDATION_THRESHOLDS.sufficientPhotoCount, 3);
  assert.equal(LANDLORD_RECOMMENDATION_THRESHOLDS.decliningMinimumPreviousViews, 5);
  assert.equal(LANDLORD_RECOMMENDATION_THRESHOLDS.promisingMinimumConversations, 3);
});