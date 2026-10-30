import assert from 'node:assert/strict';
import test from 'node:test';
import {
  inferPropertyManagementType,
  validatePropertyClassification,
} from '../services/property_classification.js';

const validLandlordFree = {
  managementType: 'landlord',
  viewingFeeType: 'free',
};

test('infers landlord management for an owner editing a legacy unspecified listing', () => {
  assert.equal(inferPropertyManagementType('unspecified', true, false), 'landlord');
});

test('does not infer landlord management for non-owners or assigned listings', () => {
  assert.equal(inferPropertyManagementType('unspecified', false, false), 'unspecified');
  assert.equal(inferPropertyManagementType('unspecified', true, true), 'unspecified');
});

test('accepts landlord-managed free viewing', () => {
  assert.equal(validatePropertyClassification(validLandlordFree, true), null);
});

test('accepts a positive paid viewing fee collected by the landlord', () => {
  assert.equal(
    validatePropertyClassification({
      managementType: 'landlord',
      viewingFeeType: 'paid',
      viewingFeeAmount: '200',
      viewingFeeCollector: 'landlord',
    }, true),
    null,
  );
});

test('requires a valid positive amount for paid viewing', () => {
  for (const amount of [null, '', 'not-a-number', 0, -1]) {
    assert.notEqual(
      validatePropertyClassification({
        managementType: 'landlord',
        viewingFeeType: 'paid',
        viewingFeeAmount: amount,
        viewingFeeCollector: 'landlord',
      }, true),
      null,
    );
  }
});

test('requires the viewing fee collector to match the management type', () => {
  assert.notEqual(
    validatePropertyClassification({
      managementType: 'agent',
      assignedAgentId: 'agent-user-id',
      viewingFeeType: 'paid',
      viewingFeeAmount: 200,
      viewingFeeCollector: 'landlord',
    }),
    null,
  );
});

test('requires an assigned agent only for agent-managed properties', () => {
  assert.notEqual(
    validatePropertyClassification({
      managementType: 'agent',
      viewingFeeType: 'free',
    }),
    null,
  );
  assert.notEqual(
    validatePropertyClassification({
      managementType: 'landlord',
      assignedAgentId: 'agent-user-id',
      viewingFeeType: 'free',
    }),
    null,
  );
});

test('keeps legacy unspecified fees distinct from free viewing', () => {
  assert.equal(
    validatePropertyClassification({
      managementType: 'unspecified',
      viewingFeeType: 'unspecified',
    }),
    null,
  );
  assert.notEqual(
    validatePropertyClassification({
      managementType: 'unspecified',
      viewingFeeType: 'unspecified',
    }, true),
    null,
  );
});

test('does not allow amounts or collectors for free viewing', () => {
  assert.notEqual(
    validatePropertyClassification({
      ...validLandlordFree,
      viewingFeeAmount: 50,
    }),
    null,
  );
  assert.notEqual(
    validatePropertyClassification({
      ...validLandlordFree,
      viewingFeeCollector: 'landlord',
    }),
    null,
  );
});

test('requires a separate assigned administrator for StayNest management', () => {
  assert.equal(
    validatePropertyClassification({
      managementType: 'staynest',
      assignedManagerId: 'admin-user-id',
      viewingFeeType: 'free',
    }),
    null,
  );
  assert.notEqual(
    validatePropertyClassification({
      managementType: 'staynest',
      viewingFeeType: 'free',
    }),
    null,
  );
  assert.notEqual(
    validatePropertyClassification({
      managementType: 'staynest',
      assignedManagerId: 'admin-user-id',
      assignedAgentId: 'agent-user-id',
      viewingFeeType: 'free',
    }),
    null,
  );
});

test('StayNest never collects viewing fees through the platform', () => {
  assert.equal(
    validatePropertyClassification({
      managementType: 'staynest',
      assignedManagerId: 'admin-user-id',
      viewingFeeType: 'paid',
      viewingFeeAmount: 200,
      viewingFeeCollector: 'landlord',
    }),
    null,
  );
  assert.notEqual(
    validatePropertyClassification({
      managementType: 'staynest',
      assignedManagerId: 'admin-user-id',
      viewingFeeType: 'paid',
      viewingFeeAmount: 200,
      viewingFeeCollector: 'staynest',
    }),
    null,
  );
});