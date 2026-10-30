ALTER TABLE properties
  ADD COLUMN IF NOT EXISTS management_type text NOT NULL DEFAULT 'unspecified',
  ADD COLUMN IF NOT EXISTS assigned_agent_id uuid REFERENCES users(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS assigned_manager_id uuid REFERENCES users(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS viewing_fee_type text NOT NULL DEFAULT 'unspecified',
  ADD COLUMN IF NOT EXISTS viewing_fee_amount numeric(10, 2),
  ADD COLUMN IF NOT EXISTS viewing_fee_collector text,
  ADD COLUMN IF NOT EXISTS viewing_fee_notes text,
  ADD COLUMN IF NOT EXISTS transparency_updated_at timestamptz,
  ADD COLUMN IF NOT EXISTS transparency_updated_by uuid REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE property_drafts
  ADD COLUMN IF NOT EXISTS viewing_fee_type text NOT NULL DEFAULT 'unspecified',
  ADD COLUMN IF NOT EXISTS viewing_fee_amount numeric(10, 2),
  ADD COLUMN IF NOT EXISTS viewing_fee_collector text,
  ADD COLUMN IF NOT EXISTS viewing_fee_notes text;

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'properties_management_type_check'
  ) THEN
    ALTER TABLE properties
      ADD CONSTRAINT properties_management_type_check
      CHECK (management_type IN ('landlord', 'agent', 'staynest', 'unspecified'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'properties_agent_assignment_check'
  ) THEN
    ALTER TABLE properties
      ADD CONSTRAINT properties_agent_assignment_check
      CHECK (
        (management_type = 'agent' AND assigned_agent_id IS NOT NULL AND assigned_manager_id IS NULL)
        OR (management_type = 'staynest' AND assigned_manager_id IS NOT NULL AND assigned_agent_id IS NULL)
        OR (management_type IN ('landlord', 'unspecified') AND assigned_agent_id IS NULL AND assigned_manager_id IS NULL)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'properties_viewing_fee_type_check'
  ) THEN
    ALTER TABLE properties
      ADD CONSTRAINT properties_viewing_fee_type_check
      CHECK (viewing_fee_type IN ('free', 'paid', 'unspecified'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'properties_viewing_fee_details_check'
  ) THEN
    ALTER TABLE properties
      ADD CONSTRAINT properties_viewing_fee_details_check
      CHECK (
        (viewing_fee_type = 'paid'
          AND viewing_fee_amount > 0
          AND viewing_fee_collector IN ('landlord', 'agent'))
        OR
        (viewing_fee_type IN ('free', 'unspecified')
          AND viewing_fee_amount IS NULL
          AND viewing_fee_collector IS NULL)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'properties_viewing_fee_collector_check'
  ) THEN
    ALTER TABLE properties
      ADD CONSTRAINT properties_viewing_fee_collector_check
      CHECK (
        viewing_fee_type <> 'paid'
        OR (management_type IN ('landlord', 'staynest') AND viewing_fee_collector = 'landlord')
        OR (management_type = 'agent' AND viewing_fee_collector = 'agent')
      );
  END IF;
END
$migration$;

CREATE INDEX IF NOT EXISTS idx_properties_assigned_agent
  ON properties(assigned_agent_id)
  WHERE assigned_agent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_properties_assigned_manager
  ON properties(assigned_manager_id)
  WHERE assigned_manager_id IS NOT NULL;