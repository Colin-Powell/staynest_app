import 'package:intl/intl.dart';

String formatReadableTimestamp(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final now = DateTime.now();
  if (_sameDay(local, now)) return DateFormat.jm().format(local);

  final yesterday = now.subtract(const Duration(days: 1));
  if (_sameDay(local, yesterday)) {
    return 'Yesterday, ${DateFormat.jm().format(local)}';
  }

  return DateFormat("MMM d, yyyy 'at' h:mm a").format(local);
}

String formatReadableTimestampString(
  String? value, {
  String fallback = '',
}) {
  final raw = value?.trim() ?? '';
  final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (dateOnly != null) {
    return formatReadableDate(
      DateTime(
        int.parse(dateOnly.group(1)!),
        int.parse(dateOnly.group(2)!),
        int.parse(dateOnly.group(3)!),
      ),
    );
  }
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? fallback : formatReadableTimestamp(parsed);
}

String formatRelativeTimestamp(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final now = DateTime.now();
  final difference = now.difference(local);

  if (difference.isNegative) {
    final remaining = difference.abs();
    if (remaining.inMinutes < 1) {
      return 'In a moment';
    }
    if (remaining.inHours < 1) {
      return 'In ${_quantity(remaining.inMinutes, 'minute')}';
    }
    if (remaining.inDays < 1) {
      return 'In ${_quantity(remaining.inHours, 'hour')}';
    }
    return 'In ${_quantity(remaining.inDays, 'day')}';
  }

  if (difference.inSeconds < 60) return 'Just now';
  if (difference.inMinutes < 60) {
    return '${_quantity(difference.inMinutes, 'minute')} ago';
  }
  if (_sameDay(local, now)) {
    return '${_quantity(difference.inHours, 'hour')} ago';
  }
  if (_sameDay(local, now.subtract(const Duration(days: 1)))) {
    return 'Yesterday';
  }
  if (difference.inDays < 7) {
    return '${_quantity(difference.inDays, 'day')} ago';
  }
  return formatReadableDate(local);
}

String formatRelativeTimestampString(
  String? value, {
  String fallback = '',
}) {
  final parsed = DateTime.tryParse(value?.trim() ?? '');
  return parsed == null ? fallback : formatRelativeTimestamp(parsed);
}

String formatReadableDate(DateTime? value) {
  if (value == null) return '';
  return DateFormat('MMM d, yyyy').format(value.toLocal());
}

String formatReadableDateString(String? value, {String fallback = ''}) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return fallback;

  final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (dateOnly != null) {
    final date = DateTime(
      int.parse(dateOnly.group(1)!),
      int.parse(dateOnly.group(2)!),
      int.parse(dateOnly.group(3)!),
    );
    return formatReadableDate(date);
  }

  final parsed = DateTime.tryParse(raw);
  return parsed == null ? fallback : formatReadableDate(parsed);
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _quantity(int count, String unit) =>
    '$count $unit${count == 1 ? '' : 's'}';
