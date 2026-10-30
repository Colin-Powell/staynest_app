import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:property_app/services/api_client.dart';

/// A standardized result object for API calls.
class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResult.success(this.data)
      : error = null,
        isSuccess = true;
  ApiResult.failure(this.error)
      : data = null,
        isSuccess = false;

  /// Executes an async action and catches any errors, returning an ApiResult.
  static Future<ApiResult<T>> run<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return ApiResult.success(result);
    } catch (e) {
      return ApiResult.failure(mapError(e));
    }
  }

  /// Maps raw exceptions or technical error strings into user-friendly messages.
  /// This prevents leaking server details like URLs or stack traces to the UI.
  static String mapError(Object err) {
    if (err is ApiException) {
      if (err.statusCode == 400 || err.statusCode == 422) {
        final message = err.message.trim();
        if (message.isNotEmpty &&
            message != 'Request failed with status ${err.statusCode}') {
          return message;
        }
      }
      return err.userMessage;
    }
    if (err is TimeoutException) {
      return 'The request timed out. Check your connection and try again.';
    }
    if (err is http.ClientException) {
      return 'Could not connect. Check your internet connection and try again.';
    }

    final technicalMessage = err.toString().toLowerCase();
    if (technicalMessage.contains('socketexception') ||
        technicalMessage.contains('failed host lookup') ||
        technicalMessage.contains('network is unreachable') ||
        technicalMessage.contains('connection refused') ||
        technicalMessage.contains('connection reset')) {
      return 'Could not connect. Check your internet connection and try again.';
    }
    if (err is FormatException) {
      return 'We received an invalid response. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
