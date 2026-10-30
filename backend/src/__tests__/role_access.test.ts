import assert from 'node:assert/strict';
import test from 'node:test';
import { hasPersistedRoleAccess } from '../middleware/role_access.js';

test('pending tenant cannot access landlord APIs', () => {
  assert.equal(
    hasPersistedRoleAccess(
      { role: 'tenant', roles: ['tenant'], landlord_verified: false },
      ['landlord', 'host'],
    ),
    false,
  );
});

test('a role without backend approval cannot access landlord APIs', () => {
  assert.equal(
    hasPersistedRoleAccess(
      { role: 'tenant', roles: ['tenant', 'landlord'], landlord_verified: false },
      ['landlord'],
    ),
    false,
  );
});

test('approved dual-role account retains tenant access and gains landlord access', () => {
  const account = {
    role: 'tenant',
    roles: ['tenant', 'landlord'],
    landlord_verified: true,
  };

  assert.equal(hasPersistedRoleAccess(account, ['tenant']), true);
  assert.equal(hasPersistedRoleAccess(account, ['landlord', 'host']), true);
});

test('tenant is allowed on routes that explicitly accept either account role', () => {
  assert.equal(
    hasPersistedRoleAccess(
      { role: 'tenant', roles: ['tenant'], landlord_verified: false },
      ['tenant', 'landlord'],
    ),
    true,
  );
});

test('approval flag without the persisted landlord role is insufficient', () => {
  assert.equal(
    hasPersistedRoleAccess(
      { role: 'tenant', roles: ['tenant'], landlord_verified: true },
      ['landlord'],
    ),
    false,
  );
});

test('approved agent can access manager APIs without changing existing tenant membership', () => {
  const account = {
    role: 'agent',
    roles: ['tenant', 'agent'],
    landlord_verified: true,
  };

  assert.equal(hasPersistedRoleAccess(account, ['agent']), true);
  assert.equal(hasPersistedRoleAccess(account, ['landlord']), true);
  assert.equal(hasPersistedRoleAccess(account, ['tenant']), true);
});

test('pending agent application cannot access manager APIs before approval', () => {
  assert.equal(
    hasPersistedRoleAccess(
      { role: 'tenant', roles: ['tenant'], landlord_verified: false },
      ['agent', 'landlord'],
    ),
    false,
  );
});

test('an unverified account with an agent role cannot access agent APIs', () => {
  assert.equal(
    hasPersistedRoleAccess(
      { role: 'agent', roles: ['tenant', 'agent'], landlord_verified: false },
      ['agent'],
    ),
    false,
  );
});