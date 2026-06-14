import 'dart:async';
import 'dart:io';

/// A standardized result object for API calls.
class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResult.success(this.data) : error = null, isSuccess = true;
  ApiResult.failure(this.error) : data = null, isSuccess = false;

  /// Maps raw exceptions or technical error strings into user-friendly messages.
  /// This prevents leaking server details like URLs or stack traces to the UI.
  static String mapError(Object err) {
    final errStr = err.toString().toLowerCase();
    
    // Keywords identifying technical/server leakage
    final bool isNetworkIssue = err is SocketException ||
        errStr.contains('socketexception') ||
        errStr.contains('connection refused') ||
        errStr.contains('connection timed out') ||
        errStr.contains('clientexception') ||
        errStr.contains('url=') ||
        errStr.contains('http status 0');

    if (isNetworkIssue) {
      return 'Unable to reach the server. Please check your internet connection.';
    }

    if (err is TimeoutException) {
      return 'The connection timed out. Please try again.';
    }

    // Fallback to a generic friendly message
    return 'Something went wrong. Please try again later.';
  }
}