import 'dart:io';
import 'package:path/path.dart' as p;

class VideoFile {
  final String path;
  final String name;
  final int size; // bytes
  final DateTime modified;

  VideoFile({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
  });

  String get extension => p.extension(name).toLowerCase();

  String get sizeLabel {
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static bool isVideoFile(String filename) {
    const videoExts = {
      '.mp4', '.mkv', '.mov', '.avi', '.webm',
      '.flv', '.wmv', '.m4v', '.3gp', '.ts', '.m2ts'
    };
    return videoExts.contains(p.extension(filename).toLowerCase());
  }

  static VideoFile? fromFile(File file) {
    try {
      final stat = file.statSync();
      return VideoFile(
        path: file.path,
        name: p.basename(file.path),
        size: stat.size,
        modified: stat.modified,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'size': size,
        'modified': modified.millisecondsSinceEpoch,
      };

  factory VideoFile.fromJson(Map<String, dynamic> json) => VideoFile(
        path: json['path'] as String,
        name: json['name'] as String,
        size: json['size'] as int,
        modified: DateTime.fromMillisecondsSinceEpoch(json['modified'] as int),
      );
}
