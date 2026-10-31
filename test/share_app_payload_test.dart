import 'package:blackhole/Helpers/app_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Share App Payload and Destinations Tests', () {
    test('AppLinks canonical share URL points to the maintained repository', () {
      expect(AppLinks.appShareUrl, 'https://github.com/thevibingteen/BlackHole');
      expect(AppLinks.githubRepoUrl, 'https://github.com/thevibingteen/BlackHole');
      expect(AppLinks.appShareUrl.contains('sangwan5688.github.io'), isFalse);
    });

    test('getShareAppPayload formats canonical outgoing share text correctly', () {
      const sharePrefix = 'Hey! Check out this cool music player app';
      final payload = AppLinks.getShareAppPayload(sharePrefix);

      expect(payload, 'Hey! Check out this cool music player app: https://github.com/thevibingteen/BlackHole');
      expect(payload.contains('sangwan5688.github.io'), isFalse);
      expect(payload.contains('thevibingteen/BlackHole'), isTrue);
    });
  });
}
