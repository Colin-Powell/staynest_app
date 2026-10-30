# Property Management and Viewing Fees

The `add-property-transparency.sql` migration is applied by the backend schema runner. Existing properties and drafts receive `unspecified` viewing-fee values; existing management values remain `unspecified` rather than inferring a manager from the landlord account or approval status.

New property creation is restricted to verified landlord accounts. The API assigns `landlord` management and requires an explicit `free` or `paid` viewing-fee choice. For paid viewing, the API requires a positive amount and a collector compatible with the management type. StayNest does not collect viewing fees or process visit payments.

Only administrators can change management assignments. Agent assignments must reference a user with the persisted `agent` role; StayNest assignments must reference a persisted administrator. Assigned agents can read and edit only their assigned property. Landlords retain access only to their own properties. Classification updates are recorded in `admin_audit_logs` and the property transparency updater fields.

The public property responses include management and fee fields for consistent card, detail, and chat-context rendering. Property approval remains separate from management identity. Search filters are not included; the stored fields are available for future filters.

Before enabling the feature in an environment, run the normal backend migration command (`npm run migrate` from `backend/`). Do not manually mark legacy records as free or StayNest-managed without verifying their actual management and fee arrangements.