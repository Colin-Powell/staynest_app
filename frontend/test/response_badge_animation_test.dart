import 'package:flutter_test/flutter_test.dart';
import 'package:property_app/widgets/response_badge_animation.dart';

void main() {
  test('response labels map to their matching animated badge assets', () {
    expect(
      responseBadgeAssetForLabel('lightning_fast'),
      'assets/images/fast.gif',
    );
    expect(
      responseBadgeAssetForLabel('quick_responder'),
      'assets/images/quick.gif',
    );
    expect(
      responseBadgeAssetForLabel('getting_faster'),
      'assets/images/improving.gif',
    );
    expect(
      responseBadgeAssetForLabel('needs_improvement'),
      'assets/images/Slow.gif',
    );
    expect(
      responseBadgeAssetForLabel('response_activity_building'),
      'assets/images/active.gif',
    );
  });
}