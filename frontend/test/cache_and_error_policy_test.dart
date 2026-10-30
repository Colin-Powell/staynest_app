import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:property_app/screens/home/cache_engine.dart';
import 'package:property_app/services/api_client.dart';
import 'package:property_app/utils/api_result.dart';
import 'package:property_app/utils/error_handler_util.dart';

void main() {
  group('request cache policy', () {
    test('scopes cached responses by user and full request URI', () {
      final uri =
          Uri.parse('https://api.staynest.test/api/messages/conversations');

      final firstUserKey = CacheEngine.requestKey(
        uri,
        userId: 'tenant-a',
        role: 'tenant',
      );
      final secondUserKey = CacheEngine.requestKey(
        uri,
        userId: 'tenant-b',
        role: 'tenant',
      );

      expect(firstUserKey, isNot(secondUserKey));
      expect(firstUserKey, contains(uri.toString()));

      final firstPageKey = CacheEngine.requestKey(
        Uri.parse(
          'https://api.staynest.test/api/messages/conversation/tenant-a?limit=50&offset=0',
        ),
        userId: 'tenant-a',
        role: 'tenant',
      );
      final secondPageKey = CacheEngine.requestKey(
        Uri.parse(
          'https://api.staynest.test/api/messages/conversation/tenant-a?limit=50&offset=50',
        ),
        userId: 'tenant-a',
        role: 'tenant',
      );
      expect(firstPageKey, isNot(secondPageKey));
    });

    test(
        'caches message and booking reads but not payment or availability checks',
        () {
      expect(
        CacheEngine.requestTtl(
          Uri.parse('https://api.staynest.test/api/messages/conversations'),
        ),
        isNotNull,
      );
      expect(
        CacheEngine.requestTtl(
          Uri.parse(
            'https://api.staynest.test/api/messages/conversation/tenant-a?limit=50&offset=0',
          ),
        ),
        isNotNull,
      );
      expect(
        CacheEngine.requestTtl(
          Uri.parse('https://api.staynest.test/api/bookings/tenant'),
        ),
        isNotNull,
      );
      expect(
        CacheEngine.requestTtl(
          Uri.parse('https://api.staynest.test/api/payments/status/abc'),
        ),
        isNull,
      );
      expect(
        CacheEngine.requestTtl(
          Uri.parse(
            'https://api.staynest.test/api/properties/id/availability-check',
          ),
        ),
        isNull,
      );
    });
  });

  group('user-facing error mapping', () {
    test('shows server validation messages for bad requests', () {
      expect(
        ApiResult.mapError(
          ApiException(
              400, 'Viewing fee collector must match the property manager.'),
        ),
        'Viewing fee collector must match the property manager.',
      );
      expect(
        ApiResult.mapError(ApiException(400, 'Request failed with status 400')),
        'Please check the information and try again.',
      );
    });

    test('does not expose server response details', () {
      final message = ApiResult.mapError(
        ApiException(
          500,
          'postgres://internal-host:5432 database stack trace',
        ),
      );

      expect(
          message, 'The service is temporarily unavailable. Please try again.');
      expect(message, isNot(contains('postgres')));
    });

    test('gives connection guidance for timeouts and unknown errors', () {
      expect(
        ApiResult.mapError(TimeoutException('request timed out')),
        contains('Check your connection'),
      );
      expect(
        ApiResult.mapError(Exception('private server details')),
        'Something went wrong. Please try again.',
      );
    });

    test('does not expose backend map messages through ErrorHandler', () {
      final serverMessage = ErrorHandler.userFacingMessage({
        'statusCode': 500,
        'message': 'postgres://internal-host:5432 database stack trace',
      });
      final clientMessage = ErrorHandler.userFacingMessage({
        'statusCode': '400',
        'message': 'private validation details',
      });

      expect(
        serverMessage,
        'The service is temporarily unavailable. Please try again.',
      );
      expect(clientMessage, 'Please check the information and try again.');
      expect(serverMessage, isNot(contains('postgres')));
      expect(clientMessage, isNot(contains('private')));
    });
  });
}
