# TODO

## Home/Search real data fixes
- [x] Update `frontend/lib/screens/home/home_view.dart` to stop using dummy fallback lists and fetch Recommended + Nearby from backend.
- [x] Add UI chip -> backend category mapping in `home_view.dart` so filtering matches real categories.
- [x] Fix image normalization + multi-image mapping in `frontend/lib/data_loader/fallback_properties_loader.dart` to prevent double-extension URLs and ensure `Property.images` is always populated.
- [ ] Ensure `frontend/lib/screens/home/search_view.dart` loads remote first (currently still relies on `FallbackPropertiesLoader`).
- [ ] Run Flutter analyze for `frontend`. 

## Maintenance
- [ ] Run `node backend/scripts/delete-all-properties-with-images.js` to wipe all property data (including images in Cloudinary)

