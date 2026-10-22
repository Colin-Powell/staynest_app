import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:property_app/screens/home/home_feed_controller.dart';

void main() {
  test('home feed explains offline and timeout failures', () {
    expect(
      describeHomeFeedLoadError(
        Exception('SocketException: Failed host lookup'),
      ),
      contains('No internet connection'),
    );
    expect(
      describeHomeFeedLoadError(TimeoutException('feed timed out')),
      contains('No internet connection'),
    );
  });

  test('home feed preserves server failure details', () {
    expect(
      describeHomeFeedLoadError(Exception('Request failed with status 503.')),
      'Could not load properties: Exception: Request failed with status 503.',
    );
  });
}