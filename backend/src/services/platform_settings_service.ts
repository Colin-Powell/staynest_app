import { query } from '../db.js';

export const defaultPlatformSettings: Record<string, Record<string, unknown>> = {
  general: {
    requireManualKyc: true,
    autoApproveListings: false,
    globalFee: 10,
    defaultCurrency: 'Ksh.',
  },
  security: {
    enforce2FA: true,
    maintenanceMode: false,
  },
};

export type GeneralPlatformSettings = {
  requireManualKyc: boolean;
  autoApproveListings: boolean;
  globalFee: number;
  defaultCurrency: string;
};

export async function ensurePlatformSettings(): Promise<void> {
  await query(`
    CREATE TABLE IF NOT EXISTS platform_settings (
      key VARCHAR(255) PRIMARY KEY,
      value JSONB NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  for (const [key, value] of Object.entries(defaultPlatformSettings)) {
    await query(
      `INSERT INTO platform_settings (key, value)
       VALUES ($1, $2::jsonb)
       ON CONFLICT (key) DO NOTHING`,
      [key, JSON.stringify(value)],
    );
  }
}

export async function getGeneralPlatformSettings(): Promise<GeneralPlatformSettings> {
  await ensurePlatformSettings();
  const result = await query<{ value: GeneralPlatformSettings }>(
    "SELECT value FROM platform_settings WHERE key = 'general'",
  );
  const value = result.rows[0]?.value;
  const settings = {
    ...defaultPlatformSettings.general,
    ...(value ?? {}),
  } as GeneralPlatformSettings;
  const fee = Number(settings.globalFee);
  if (!Number.isFinite(fee) || fee < 0 || fee > 100) {
    throw new Error('The configured platform fee is invalid.');
  }
  return { ...settings, globalFee: fee };
}