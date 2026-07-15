# TODO

- [ ] Add fix for GET /api/properties/nearby crashing with invalid uuid input syntax (string "nearby").
  - [ ] Implement new router.get('/nearby', ...) in backend/src/routes/properties.ts before router.get('/:id', ...).
  - [ ] Support lat/lng/radius and optionally user location from tenant_profiles (location catch) when available.
  - [ ] Ensure invalid 'nearby' param never gets treated as :id UUID by defining explicit /nearby route.
- [ ] Update frontend (if needed) to call correct endpoint.
- [ ] Run backend tests / quick manual curl to confirm 200 response.

