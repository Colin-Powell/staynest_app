import 'package:flutter/material.dart';

class ErrorScreen extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ErrorScreen({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 100, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                'Something went wrong',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message ??
                    'We are having trouble connecting to the StayNest servers. Please check your connection.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onRetry ??
                      () => Navigator.of(context).pushReplacementNamed('/'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueAccent,
                  ),
                  child: Text(onRetry != null ? 'Try Again' : 'Back to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
