export interface PersistedAccountRoles {
  role?: string;
  roles?: string[];
  landlord_verified?: boolean;
}

export function hasPersistedRoleAccess(
  account: PersistedAccountRoles,
  allowedRoles: string[],
): boolean {
  const normalizedAllowed = allowedRoles.map((role) => role.toLowerCase());
  const roles = Array.isArray(account.roles)
    ? account.roles.map((role) => role.toLowerCase())
    : [account.role?.toLowerCase() ?? ''];
  const hasLandlordAccess =
    account.landlord_verified === true &&
    roles.some((role) => role === 'landlord' || role === 'host' || role === 'agent');

  return normalizedAllowed.some((role) => {
    if (role === 'landlord' || role === 'host') return hasLandlordAccess;
    if (role === 'agent') return hasLandlordAccess && roles.includes('agent');
    return roles.includes(role);
  });
}