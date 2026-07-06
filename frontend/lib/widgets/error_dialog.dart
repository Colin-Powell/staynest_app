import 'package:flutter/material.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onDismiss;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title,
          style: const TextStyle(
              color: Colors.redAccent, fontWeight: FontWeight.bold)),
      content: Text(message),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            if (onDismiss != null) onDismiss!();
          },
          child:
              const Text('Dismiss', style: TextStyle(color: Colors.blueGrey)),
        ),
      ],
    );
  }
}
