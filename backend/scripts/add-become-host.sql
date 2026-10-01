ALTER TABLE users
  ADD COLUMN IF NOT EXISTS roles text[] NOT NULL DEFAULT ARRAY['tenant']::text[],
  ADD COLUMN IF NOT EXISTS landlord_verified boolean NOT NULL DEFAULT false;

UPDATE users
SET roles = CASE
  WHEN role IN ('landlord', 'host') THEN ARRAY['tenant', role]::text[]
  WHEN role = ANY(ARRAY['admin', 'super_admin', 'administrator']) THEN ARRAY[role]::text[]
  ELSE ARRAY['tenant']::text[]
END
WHERE roles = ARRAY['tenant']::text[] AND role <> 'tenant';

UPDATE users
SET landlord_verified = true,
    roles = CASE
      WHEN 'landlord' = ANY(roles) THEN roles
      ELSE array_append(roles, 'landlord')
    END
WHERE role IN ('landlord', 'host')
  AND EXISTS (
    SELECT 1 FROM verifications v
    WHERE v.user_id = users.id AND v.status = 'approved'
  );

ALTER TABLE verifications
  ADD COLUMN IF NOT EXISTS reminder_stage smallint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reminder_sent_at timestamptz,
  ADD COLUMN IF NOT EXISTS submitted_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;

CREATE INDEX IF NOT EXISTS verifications_user_status_created_idx
  ON verifications(user_id, status, created_at DESC);