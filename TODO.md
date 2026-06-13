# TODO

## Fix Dart static analysis errors (RemoteDatabaseRepository + review fallback)
- [ ] Inspect and fix `frontend/lib/repository/remote_database_repository.dart`:
  - [ ] Remove duplicate `fetchPropertyReviews` and ensure correct return types.
  - [ ] Fix `_authHeaders` undefined usage (either define it or remove it).
  - [ ] Ensure `submitReview` signature matches UI usage (`submitReview` params include `bookingId`).
- [ ] Fix `frontend/lib/data_loader/fallback_properties_loader.dart` `loadAll()` type errors.
- [ ] Re-run `flutter analyze` to confirm remaining errors.
- [ ] Run unit/widget smoke checks (build) if analysis passes.

