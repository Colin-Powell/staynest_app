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