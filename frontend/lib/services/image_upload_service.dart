import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:property_app/services/uploads.dart';
import 'package:property_app/session/app_session.dart';

class UploadProgress {
  final File file;
  final double progress;
  final String? url;
  final String status;

  const UploadProgress({
    required this.file,
    required this.progress,
    this.url,
    required this.status,
  });

  UploadProgress copyWith({
    double? progress,
    String? url,
    String? status,
  }) {
    return UploadProgress(
      file: file,
      progress: progress ?? this.progress,
      url: url ?? this.url,
      status: status ?? this.status,
    );
  }
}

Future<File> _compressFile(String filePath) async {
  final file = File(filePath);
  return ImageUploadService.compressImageFile(file);
}

class ImageUploadService {
  static const int _maxConcurrentUploads = 4;

  static Future<File> compressImageFile(File input) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = path.join(
      tempDir.path,
      'staynest_compressed_${DateTime.now().millisecondsSinceEpoch}_${path.basenameWithoutExtension(input.path)}.webp',
    );

    final xfile = await FlutterImageCompress.compressAndGetFile(
      input.absolute.path,
      targetPath,
      quality: 82,
      format: CompressFormat.webp,
      keepExif: false,
      minWidth: 1280,
      minHeight: 720,
    );

    return xfile == null ? input : File(xfile.path);
  }

  static Future<List<File>> compressSelectedImages(List<File> selected) async {
    final futures = selected.map((file) => compute(_compressFile, file.path));
    return Future.wait(futures);
  }

  static Future<List<String>> uploadImages(
    List<File> files,
    void Function(List<UploadProgress> progress) onProgress,
  ) async {
    final queue = <File>[...files];
    final inProgress = <File, UploadTask>{};
    final results = <File, String>{};
    final progressState = {
      for (var file in files)
        file: UploadProgress(
            file: file, progress: 0.0, url: null, status: 'queued')
    };

    void emitProgress() {
      onProgress(progressState.values.toList());
        }

    Future<void> startUpload(File file) async {
      final task = UploadsService.uploadFileWithProgress(
        file,
        (p) {
          progressState[file] = progressState[file]!.copyWith(
            progress: p,
            status: p >= 1.0 ? 'finalizing' : 'uploading',
          );
          emitProgress();
        },
        token: AppSession.apiToken,
      );
      inProgress[file] = task;
      progressState[file] = progressState[file]!.copyWith(status: 'uploading');
      emitProgress();

      final url = await task.future;
      results[file] = url;
      progressState[file] = progressState[file]!.copyWith(
        progress: 1.0,
        url: url,
        status: 'completed',
      );
      emitProgress();
      inProgress.remove(file);
    }

    while (queue.isNotEmpty || inProgress.isNotEmpty) {
      while (queue.isNotEmpty && inProgress.length < _maxConcurrentUploads) {
        final file = queue.removeAt(0);
        unawaited(startUpload(file));
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    emitProgress();

    if (results.length != files.length) {
      throw Exception('One or more image uploads failed.');
    }

    return files.map((file) => results[file]!).toList();
  }
}
