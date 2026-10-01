import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:property_app/session/app_session.dart';
import 'package:property_app/repository/http_json_client.dart';

/// Represents an in-progress upload that can be awaited and cancelled.
class UploadTask {
  final Future<String> future;
  final void Function() cancel;
  UploadTask(this.future, this.cancel);
}

class UploadCancelledException implements Exception {
  @override
  String toString() => 'Upload cancelled by user';
}

class UploadsService {
  /// Uploads a single file synchronously to the backend /uploads endpoint.
  static Future<String> uploadFile(File file,
      {String? token, String? idempotencyKey}) async {
    final base = AppSession.apiBaseUrl;
    final uri = Uri.parse("$base/uploads");
    bool tokenRefreshed = false;

    while (true) {
      final request = http.MultipartRequest('POST', uri);
      if ((token ?? AppSession.apiToken) != null) {
        request.headers['Authorization'] =
            'Bearer ${token ?? AppSession.apiToken}';
      }
      if (idempotencyKey != null) {
        request.headers['Idempotency-Key'] = idempotencyKey;
      }
      final multipart = await http.MultipartFile.fromPath('file', file.path);
      request.files.add(multipart);

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401 && !tokenRefreshed) {
        tokenRefreshed = true;
        try {
          await HttpJsonClient().refreshAccessTokenIfPossible();
          token = null;
          continue;
        } catch (_) {}
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Upload failed:  ');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'];
      final url = (data is Map ? data['url'] : null) ?? decoded['url'];

      if (url == null) throw Exception('Upload returned no URL');
      return url as String;
    }
  }

  /// Uploads a file asynchronously using BullMQ worker via /uploads/async
  /// and polls the job status until it is completed, reporting progress via [onProgress] (0.0 - 1.0).
  static UploadTask uploadFileWithProgress(
      File file, void Function(double) onProgress,
      {String? token, String? idempotencyKey}) {
    return uploadXFileWithProgress(
      XFile(file.path),
      onProgress,
      token: token,
      idempotencyKey: idempotencyKey,
    );
  }

  static UploadTask uploadXFileWithProgress(
      XFile file, void Function(double) onProgress,
      {String? token, String? idempotencyKey}) {
    final client = http.Client();
    final completer = Completer<String>();
    bool isCancelled = false;

    () async {
      final base = AppSession.apiBaseUrl;
      final uri = Uri.parse("$base/uploads/async");

      try {
        final total = await file.length();
        String? jobId;
        bool tokenRefreshed = false;

        while (true) {
          final request = http.MultipartRequest('POST', uri);
          if ((token ?? AppSession.apiToken) != null) {
            request.headers['Authorization'] =
                'Bearer ${token ?? AppSession.apiToken}';
          }
          if (idempotencyKey != null) {
            request.headers['Idempotency-Key'] = idempotencyKey;
          }

          int bytesSent = 0;
          final stream = file.openRead().transform(
              StreamTransformer.fromHandlers(
                  handleData: (List<int> data, EventSink<List<int>> sink) {
            bytesSent += data.length;
            try {
              onProgress((bytesSent / total) * 0.8);
            } catch (_) {}
            sink.add(data);
          }));

          final multipart = http.MultipartFile('file', stream, total,
              filename: path.basename(file.name));
          request.files.add(multipart);

          final streamed = await client.send(request);
          final response = await http.Response.fromStream(streamed);

          if (response.statusCode == 401 && !tokenRefreshed) {
            tokenRefreshed = true;
            try {
              await HttpJsonClient().refreshAccessTokenIfPossible();
              token = null;
              continue;
            } catch (_) {
              throw Exception(
                  'Async Upload failed: 401 Unauthorized (Refresh failed)');
            }
          }

          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw Exception(
                'Async upload failed (${response.statusCode}): ${response.body}');
          }

          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final data = decoded['data'];
          jobId = data['jobId'];
          break;
        }

        if (jobId == null) throw Exception('Upload did not return a Job ID');

        // Poll for job completion
        String? finalUrl;
        int attempts = 0;
        const maxAttempts = 60; // 2 minutes timeout
        bool pollTokenRefreshed = false;

        while (!isCancelled) {
          if (attempts >= maxAttempts)
            throw Exception('Upload timed out while processing');
          attempts++;
          await Future.delayed(const Duration(seconds: 2));
          if (isCancelled) break;

          final jobRes = await client.get(Uri.parse("$base/uploads/job/$jobId"),
              headers: {
                'Authorization': 'Bearer ${token ?? AppSession.apiToken}'
              });

          if (jobRes.statusCode == 401 && !pollTokenRefreshed) {
            pollTokenRefreshed = true;
            try {
              await HttpJsonClient().refreshAccessTokenIfPossible();
              token = null;
              attempts--; // don't count this attempt
              continue;
            } catch (_) {}
          }

          if (jobRes.statusCode == 200) {
            final jobData = jsonDecode(jobRes.body)['data'];
            final status = jobData['status'];

            if (status == 'completed') {
              finalUrl =
                  jobData['result']['url'] ?? jobData['result']['secure_url'];
              break;
            } else if (status == 'failed') {
              throw Exception(
                  'Background media processing failed: ${jobData['error'] ?? 'unknown error'}');
            } else {
              try {
                onProgress(0.9); // Processing...
              } catch (_) {}
            }
          }
        }

        if (isCancelled) {
          throw UploadCancelledException();
        }

        if (finalUrl == null)
          throw Exception('Job finished but no URL was returned');

        try {
          onProgress(1.0);
        } catch (_) {}
        if (!completer.isCompleted) completer.complete(finalUrl as String);
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      } finally {
        try {
          client.close();
        } catch (_) {}
      }
    }();

    return UploadTask(completer.future, () {
      isCancelled = true;
      try {
        if (!completer.isCompleted) {
          completer.completeError(UploadCancelledException());
        }
      } catch (_) {}
      try {
        client.close();
      } catch (_) {}
    });
  }
}
