import 'package:flutter_test/flutter_test.dart';
import 'package:property_app/widgets/property_image.dart';

void main() {
  group('sanitizeImageDimension', () {
    test('returns null for non-finite values', () {
      expect(sanitizeImageDimension(double.infinity), isNull);
      expect(sanitizeImageDimension(double.nan), isNull);
    });

    test('preserves finite positive values', () {
      expect(sanitizeImageDimension(120), 120);
      expect(sanitizeImageDimension(0), isNull);
    });
  });
}
