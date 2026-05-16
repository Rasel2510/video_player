import 'package:path/path.dart' as p;
import 'video_file.dart';

class VideoFolder {
  final String path;
  final List<VideoFile> videos;

  VideoFolder({required this.path, required this.videos});

  /// The display name of the folder (last path segment).
  String get name => p.basename(path).isEmpty ? path : p.basename(path);

  int get videoCount => videos.length;

  /// Total size of all videos in this folder (bytes).
  int get totalSize => videos.fold(0, (sum, v) => sum + v.size);

  String get totalSizeLabel {
    final bytes = totalSize;
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
