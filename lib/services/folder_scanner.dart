import 'dart:io';
import '../models/video_file.dart';

class FolderScanner {
  /// Returns all video files directly inside [dirPath] (non-recursive).
  static List<VideoFile> listVideosInDir(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];

    final files = <VideoFile>[];
    try {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is File && VideoFile.isVideoFile(entity.path)) {
          final vf = VideoFile.fromFile(entity);
          if (vf != null) files.add(vf);
        }
      }
    } catch (_) {}

    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return files;
  }

  /// Returns all video files recursively inside [dirPath].
  static Future<List<VideoFile>> scanRecursive(
    String dirPath, {
    void Function(int found)? onProgress,
  }) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];

    final files = <VideoFile>[];
    await _recurse(dir, files, onProgress);
    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return files;
  }

  static Future<void> _recurse(
    Directory dir,
    List<VideoFile> out,
    void Function(int)? onProgress,
  ) async {
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && VideoFile.isVideoFile(entity.path)) {
          final vf = VideoFile.fromFile(entity);
          if (vf != null) {
            out.add(vf);
            onProgress?.call(out.length);
          }
        } else if (entity is Directory) {
          await _recurse(entity, out, onProgress);
        }
      }
    } catch (_) {}
  }

  /// Lists subdirectories and video files in [dirPath] for the folder browser.
  static FolderContents listDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return FolderContents(dirs: [], videos: []);
    }

    final dirs = <Directory>[];
    final videos = <VideoFile>[];

    try {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is Directory) {
          // Skip hidden dirs
          final name = entity.path.split(Platform.pathSeparator).last;
          if (!name.startsWith('.')) dirs.add(entity);
        } else if (entity is File && VideoFile.isVideoFile(entity.path)) {
          final vf = VideoFile.fromFile(entity);
          if (vf != null) videos.add(vf);
        }
      }
    } catch (_) {}

    dirs.sort((a, b) {
      final na = a.path.split(Platform.pathSeparator).last.toLowerCase();
      final nb = b.path.split(Platform.pathSeparator).last.toLowerCase();
      return na.compareTo(nb);
    });
    videos.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return FolderContents(dirs: dirs, videos: videos);
  }
}

class FolderContents {
  final List<Directory> dirs;
  final List<VideoFile> videos;
  FolderContents({required this.dirs, required this.videos});
}
