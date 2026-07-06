# TODO

- [ ] Fix Flutter/Dart analyzer errors in `frontend/lib/screens/property/commute_methods_view.dart`:
  - [ ] Replace incorrect `NotificationListener<MapPositionChangedNotification>` usage with FlutterMap-supported gesture/pan detection (remove fake `MapPositionChangedNotification` type).
  - [ ] Ensure `Path` usage in custom painters uses correct dart:ui `Path` API (keep/verify `dart:ui` import) and remove any generic/incorrect Path typing.
  - [ ] Run `flutter analyze` (or `dart analyze` from frontend) to confirm errors are resolved.

