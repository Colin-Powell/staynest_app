export const MAX_HOME_FEED_LOCATION_SECTIONS = 10;
export const MAX_HOME_FEED_PROPERTIES_PER_LOCATION = 10;

export function publicPropertyLocationSql(alias = 'p'): string {
  return `COALESCE(
    NULLIF(BTRIM(${alias}.county), ''),
    NULLIF(BTRIM(${alias}.sub_county), ''),
    NULLIF(BTRIM(${alias}.town), ''),
    NULLIF(BTRIM(${alias}.city), ''),
    NULLIF(BTRIM(${alias}.neighborhood), ''),
    NULLIF(BTRIM(${alias}.estate_village), ''),
    NULLIF(BTRIM(${alias}.ward), '')
  )`;
}