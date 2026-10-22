import 'package:intl/intl.dart';

String presenceLabel({required bool online, DateTime? lastSeenAt}) {
  if (online) return 'Online';
  if (lastSeenAt == null) return 'Last seen unavailable';

  final localTime = lastSeenAt.toLocal();
  final difference = DateTime.now().difference(localTime);
  if (difference.inMinutes < 1) return 'Last seen just now';
  if (difference.inHours < 1) return 'Last seen ${difference.inMinutes}m ago';
  if (difference.inDays < 1) return 'Last seen ${difference.inHours}h ago';
  if (difference.inDays == 1) return 'Last seen yesterday';
  if (difference.inDays < 7) return 'Last seen ${difference.inDays}d ago';
  return 'Last seen ${DateFormat('MMM d, y · h:mm a').format(localTime)}';
}
