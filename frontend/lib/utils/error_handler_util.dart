import 'package:flutter/material.dart';
import 'package:property_app/services/api_client.dart';
import 'package:property_app/utils/api_result.dart';
import '../widgets/error_dialog.dart';
import '../screens/error_screen.dart';

class ErrorHandler {
  /// Unified error handler for API calls
  static void handle(BuildContext context, dynamic error) {
    final statusCode = _statusCode(error);
    final message = userFacingMessage(error);

    if (statusCode >= 500 || statusCode == 0) {
      // Fatal errors or connectivity issues
      _showErrorScreen(context, message);
    } else {
      // Client errors (400, 401, 403, 404)
      _showErrorModal(context, message);
    }
  }

  static String userFacingMessage(Object? error) {
    if (error is Map) {
      final statusCode = _statusCode(error);
      return statusCode == 0
          ? 'Something went wrong. Please try again.'
          : ApiException(statusCode, '').userMessage;
    }
    return ApiResult.mapError(error ?? Exception());
  }

  static int _statusCode(Object? error) {
    if (error is ApiException) return error.statusCode;
    if (error is Map) {
      return int.tryParse(error['statusCode']?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  static void _showErrorModal(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => ErrorDialog(title: 'Oops!', message: message),
    );
  }

  static void _showErrorScreen(BuildContext context, String message) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ErrorScreen(message: message)),
    );
  }
}
