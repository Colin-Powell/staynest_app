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

  test('insecure cloudinary image urls are upgraded to https', () {
    final url = resolvePropertyImageUrl(
      'http://res.cloudinary.com/demo/image/upload/staynest/hero.webp',
    );

    expect(url, startsWith('https://res.cloudinary.com/'));
    expect(url, isNot(startsWith('http://')));
  });

  test('local image urls keep their configured scheme', () {
    const url = 'http://localhost:8080/uploads/hero.webp';

    expect(resolvePropertyImageUrl(url), url);
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
