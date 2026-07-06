import 'package:flutter/material.dart';
import '../widgets/error_dialog.dart';
import '../screens/error_screen.dart';

class ErrorHandler {
  /// Unified error handler for API calls
  static void handle(BuildContext context, dynamic error) {
    // Example logic: Extract code and message from your standard backend response
    String message = 'An unexpected error occurred';
    int statusCode = 0;

    if (error is Map<String, dynamic>) {
      message = error['message'] ?? message;
      statusCode = error['statusCode'] ?? 0;
    }

    if (statusCode >= 500 || statusCode == 0) {
      // Fatal errors or connectivity issues
      _showErrorScreen(context, message);
    } else {
      // Client errors (400, 401, 403, 404)
      _showErrorModal(context, message);
    }
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
