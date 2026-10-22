export const DEFAULT_PUBLIC_PROPERTY_CATEGORY = 'Apartment';

export function normalizePublicPropertyCategory(category: unknown): string {
  if (typeof category !== 'string' || category.trim().length === 0) {
    return DEFAULT_PUBLIC_PROPERTY_CATEGORY;
  }
  return category.trim();
}

export function publicPropertyCategorySql(alias = 'p'): string {
  return `COALESCE(NULLIF(BTRIM(${alias}.category), ''), '${DEFAULT_PUBLIC_PROPERTY_CATEGORY}')`;
}