import 'package:flutter_test/flutter_test.dart';
import 'package:property_app/utils/date_time_format.dart';

void main() {
  group('readable date/time formatting', () {
    test('date-only API values do not shift by timezone', () {
      expect(formatReadableDateString('2026-10-26'), 'Oct 26, 2026');
    });

    test('timestamps include a readable local time', () {
      expect(
        formatReadableTimestamp(DateTime.now()),
        matches(RegExp(r'\d{1,2}:\d{2}')),
      );
    });

    test('recent timestamps use natural relative wording', () {
      expect(
        formatRelativeTimestamp(
          DateTime.now().subtract(const Duration(minutes: 2)),
        ),
        '2 minutes ago',
      );
    });

    test('invalid timestamp strings use the supplied fallback', () {
      expect(
        formatReadableTimestampString('not-a-timestamp', fallback: 'N/A'),
        'N/A',
      );
    });
  });
}
