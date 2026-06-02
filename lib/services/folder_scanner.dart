import 'dart:io';
import 'dart:isolate';
import '../models/video_file.dart';
import '../models/video_folder.dart';

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

  /// Returns all video files recursively inside [dirPath], using an isolate.
  static Future<List<VideoFile>> scanRecursive(
    String dirPath, {
    void Function(int found)? onProgress,
  }) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(
      _isolateScanRecursive,
      _IsolateScanData(dirPath, receivePort.sendPort),
    );

    List<VideoFile>? finalResult;
    await for (final message in receivePort) {
      if (message is int) {
        onProgress?.call(message);
      } else if (message is List<VideoFile>) {
        finalResult = message;
        receivePort.close();
      }
    }
    return finalResult ?? [];
  }

  static Future<void> _isolateScanRecursive(_IsolateScanData data) async {
    final dir = Directory(data.rootPath);
    if (!dir.existsSync()) {
      data.sendPort.send(<VideoFile>[]);
      return;
    }

    final files = <VideoFile>[];
    await _recurse(dir, files, (count) => data.sendPort.send(count));
    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    data.sendPort.send(files);
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
            // FIX #8: only send progress every 25 files to avoid flooding
            // the main isolate with thousands of state updates
            if (out.length % 25 == 0) onProgress?.call(out.length);
          }
        } else if (entity is Directory) {
          await _recurse(entity, out, onProgress);
        }
      }
    } catch (_) {}
  }

  /// Scans [rootPath] recursively and groups videos by folder, using an isolate.
  static Future<List<VideoFolder>> scanFolders(
    String rootPath, {
    void Function(int found)? onProgress,
  }) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(
      _isolateScanFolders,
      _IsolateScanData(rootPath, receivePort.sendPort),
    );

    List<VideoFolder>? finalResult;
    await for (final message in receivePort) {
      if (message is int) {
        onProgress?.call(message);
      } else if (message is List<VideoFolder>) {
        finalResult = message;
        receivePort.close();
      }
    }
    return finalResult ?? [];
  }

  static Future<void> _isolateScanFolders(_IsolateScanData data) async {
    final dir = Directory(data.rootPath);
    if (!dir.existsSync()) {
      data.sendPort.send(<VideoFolder>[]);
      return;
    }

    final Map<String, List<VideoFile>> folderMap = {};
    int totalFiles = 0;
    await _recurseForFolders(dir, folderMap, (count) {
      totalFiles = count;
      data.sendPort.send(totalFiles);
    });

    final folders = folderMap.entries.map((e) {
      final videos = e.value
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return VideoFolder(path: e.key, videos: videos);
    }).toList();

    folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    data.sendPort.send(folders);
  }

  static Future<void> _recurseForFolders(
    Directory dir,
    Map<String, List<VideoFile>> out,
    void Function(int)? onProgress,
  ) async {
    try {
      final List<VideoFile> videosInThisDir = [];
      final List<Directory> subDirs = [];

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && VideoFile.isVideoFile(entity.path)) {
          final vf = VideoFile.fromFile(entity);
          if (vf != null) videosInThisDir.add(vf);
        } else if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (!name.startsWith('.')) subDirs.add(entity);
        }
      }

      if (videosInThisDir.isNotEmpty) {
        out[dir.path] = videosInThisDir;
        final total = out.values.fold(0, (s, v) => s + v.length);
        // FIX #8: throttle — only notify every 25 videos found
        if (total % 25 == 0) onProgress?.call(total);
      }

      for (final sub in subDirs) {
        await _recurseForFolders(sub, out, onProgress);
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
    videos.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return FolderContents(dirs: dirs, videos: videos);
  }
}

class FolderContents {
  final List<Directory> dirs;
  final List<VideoFile> videos;
  FolderContents({required this.dirs, required this.videos});
}

class _IsolateScanData {
  final String rootPath;
  final SendPort sendPort;
  _IsolateScanData(this.rootPath, this.sendPort);
}
