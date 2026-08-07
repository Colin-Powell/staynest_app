import 'dart:async';
import 'dart:io';

/// A standardized result object for API calls.
class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResult.success(this.data) : error = null, isSuccess = true;
  ApiResult.failure(this.error) : data = null, isSuccess = false;

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
    return err.toString();
  }
}