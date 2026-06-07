# TODO

## VisibilityDetector dependency fix
- [ ] Inspect pubspec.yaml for `visibility_detector` dependency (already: missing).
- [ ] Add `visibility_detector` to `frontend/pubspec.yaml`.
- [ ] Run `flutter pub get` (frontend) to fetch the package.
- [ ] Re-run `flutter analyze` / `flutter test` to confirm HomeView and SearchView compile.
- [ ] If any remaining compile errors (e.g., in search_view.dart around line ~538), fix them.

