import 'package:flutter_test/flutter_test.dart';
import 'package:property_app/utils/property_image_url.dart';

void main() {
  test('cloudinary urls are optimized for faster delivery', () {
    final url = resolvePropertyImageUrl(
      'https://res.cloudinary.com/demo/image/upload/staynest/hero.jpg',
    );

    expect(url, contains('f_auto'));
    expect(url, contains('q_auto'));
  });

  test('video cloudinary urls use https without image transformations', () {
    final url = resolvePropertyVideoUrl(
      'http://res.cloudinary.com/demo/video/upload/staynest/tour.mp4',
    );

    expect(
        url, 'https://res.cloudinary.com/demo/video/upload/staynest/tour.mp4');
    expect(url, isNot(contains('f_auto')));
  });
}
