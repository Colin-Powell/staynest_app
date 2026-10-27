import 'package:property_app/utils/date_time_format.dart';

String presenceLabel({required bool online, DateTime? lastSeenAt}) {
  if (online) return 'Online';
  if (lastSeenAt == null) return 'Last seen unavailable';

  return 'Last seen ${formatRelativeTimestamp(lastSeenAt)}';
}
