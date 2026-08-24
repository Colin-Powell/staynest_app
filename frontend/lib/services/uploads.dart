import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:property_app/session/app_session.dart';

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
  /// Uploads a single file to the backend `/uploads` endpoint and returns the public URL.
  static Future<String> uploadFile(File file, {String? token, String? idempotencyKey}) async {
    final base = AppSession.apiBaseUrl; // e.g. http://10.0.2.2:8080/api
    final uri = Uri.parse('$base/uploads');
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
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Upload failed: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    final url = (data is Map ? data['url'] : null) ?? decoded['url'];

    if (url == null) throw Exception('Upload returned no URL');
    return url as String;
  }

  /// Uploads a file while reporting progress via [onProgress] (0.0 - 1.0).
  /// Returns an [UploadTask] with a `future` and a `cancel()` method.
  static UploadTask uploadFileWithProgress(
      File file, void Function(double) onProgress,
      {String? token, String? idempotencyKey}) {
    final client = http.Client();
    final completer = Completer<String>();

    () async {
      final base = AppSession.apiBaseUrl;
      final uri = Uri.parse('$base/uploads');
      final request = http.MultipartRequest('POST', uri);
      if ((token ?? AppSession.apiToken) != null) {
        request.headers['Authorization'] =
            'Bearer ${token ?? AppSession.apiToken}';
      }
      if (idempotencyKey != null) {
        request.headers['Idempotency-Key'] = idempotencyKey;
      }

      try {
        final total = await file.length();
        int bytesSent = 0;

        final stream = file.openRead().transform(StreamTransformer.fromHandlers(
            handleData: (List<int> data, EventSink<List<int>> sink) {
          bytesSent += data.length;
          try {
            onProgress(bytesSent / total);
          } catch (_) {}
          sink.add(data);
        }));

        final multipart = http.MultipartFile('file', stream, total,
            filename: path.basename(file.path));
        request.files.add(multipart);

        final streamed = await client.send(request);
        final response = await http.Response.fromStream(streamed);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
              'Upload failed: ${response.statusCode} ${response.body}');
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'];
        final url = (data is Map ? data['url'] : null) ?? decoded['url'];

        if (url == null) throw Exception('Upload returned no URL');
        try {
          onProgress(1.0);
        } catch (_) {}
        if (!completer.isCompleted) completer.complete(url as String);
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      } finally {
        try {
          client.close();
        } catch (_) {}
      }
    }();

    return UploadTask(completer.future, () {
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
