ALTER TABLE properties
  DROP CONSTRAINT IF EXISTS properties_viewing_fee_details_check,
  DROP CONSTRAINT IF EXISTS properties_viewing_fee_collector_check;

UPDATE properties
SET management_type = 'staynest',
    assigned_manager_id = landlord_id,
    assigned_agent_id = NULL,
    viewing_fee_collector = CASE
      WHEN viewing_fee_type = 'paid' THEN 'staynest'
      ELSE NULL
    END
WHERE landlord_id = '4e38b356-8cc8-428c-b005-123d61a42f7b'::uuid;

UPDATE properties
SET viewing_fee_collector = 'staynest'
WHERE management_type = 'staynest'
  AND viewing_fee_type = 'paid';

ALTER TABLE properties
  ADD CONSTRAINT properties_viewing_fee_details_check
  CHECK (
    (viewing_fee_type = 'paid'
      AND viewing_fee_amount > 0
      AND viewing_fee_collector IN ('landlord', 'agent', 'staynest'))
    OR
    (viewing_fee_type IN ('free', 'unspecified')
      AND viewing_fee_amount IS NULL
      AND viewing_fee_collector IS NULL)
  ),
  ADD CONSTRAINT properties_viewing_fee_collector_check
  CHECK (
    viewing_fee_type <> 'paid'
    OR (management_type = 'landlord' AND viewing_fee_collector = 'landlord')
    OR (management_type = 'agent' AND viewing_fee_collector = 'agent')
    OR (management_type = 'staynest' AND viewing_fee_collector = 'staynest')
  );
