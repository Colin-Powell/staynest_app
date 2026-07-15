import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/image_upload_service.dart';

class AvatarService {
  /// Upload avatar image to backend `/api/uploads`.
  /// Returns the Cloudinary `public_id` stored as `users.avatar`.
  static Future<String> uploadAvatar(File file) async {
    final uri = Uri.parse('${AppSession.apiBaseUrl}/uploads');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer ${AppSession.apiToken ?? ''}';

    final compressedFile = await ImageUploadService.compressImageFile(file);

    final length = await compressedFile.length();
    if (length == 0) {
      throw Exception('Selected image is empty');
    }

    final multipartFile = await http.MultipartFile.fromPath('file', compressedFile.path);
    request.files.add(multipartFile);

    final streamed = await request.send();
    final responseBody = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      debugPrint('Avatar upload failed ${streamed.statusCode}: $responseBody');
      throw Exception('Avatar upload failed');
    }

    final decoded = await computeJson(responseBody);
    final data = decoded['data'];
    final filename = data is Map ? data['filename'] : null;
    if (filename is String && filename.isNotEmpty) {
      return filename; // Cloudinary public_id (per backend uploads.ts)
    }

    // Fallback: if backend ever returns url/public_id directly.
    final publicId = data is Map ? data['public_id'] : null;
    if (publicId is String && publicId.isNotEmpty) return publicId;

    throw Exception('Avatar upload returned unexpected payload');
  }
}

Future<Map<String, dynamic>> computeJson(String body) async {
  if (body.trim().isEmpty) return <String, dynamic>{};
  return jsonDecode(body) as Map<String, dynamic>;
}
