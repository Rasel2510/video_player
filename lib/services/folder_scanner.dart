import 'package:path/path.dart' as p;
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
          if (vf != null && vf.size >= 1024) files.add(vf);
        }
      }
    } catch (_) {}

    // Precompute lowercased names so toLowerCase() isn't called O(n log n)
    // times by the sort comparator — once per element instead.
    final keys = {for (final f in files) f: f.name.toLowerCase()};
    files.sort((a, b) => keys[a]!.compareTo(keys[b]!));
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
    _recurseSync(dir, files, (count) => data.sendPort.send(count));
    final keys = {for (final f in files) f: f.name.toLowerCase()};
    files.sort((a, b) => keys[a]!.compareTo(keys[b]!));
    data.sendPort.send(files);
  }

  static void _recurseSync(
    Directory dir,
    List<VideoFile> out,
    void Function(int)? onProgress,
  ) {
    try {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is File && VideoFile.isVideoFile(entity.path)) {
          final vf = VideoFile.fromFile(entity);
          if (vf != null && vf.size >= 1024) {
            out.add(vf);
            if (out.length % 25 == 0) onProgress?.call(out.length);
          }
        } else if (entity is Directory) {
          _recurseSync(entity, out, onProgress);
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
    _recurseForFoldersSync(dir, folderMap, 0, (count) {
      data.sendPort.send(count);
    });

    final folders = folderMap.entries.map((e) {
      final videos = e.value;
      final vkeys = {for (final v in videos) v: v.name.toLowerCase()};
      videos.sort((a, b) => vkeys[a]!.compareTo(vkeys[b]!));
      return VideoFolder(path: e.key, videos: videos);
    }).toList();

    final fkeys = {for (final f in folders) f: f.name.toLowerCase()};
    folders.sort((a, b) => fkeys[a]!.compareTo(fkeys[b]!));
    data.sendPort.send(folders);
  }

  static int _recurseForFoldersSync(
    Directory dir,
    Map<String, List<VideoFile>> out,
    int currentTotal,
    void Function(int)? onProgress,
  ) {
    try {
      final List<VideoFile> videosInThisDir = [];
      final List<Directory> subDirs = [];

      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is File && VideoFile.isVideoFile(entity.path)) {
          final vf = VideoFile.fromFile(entity);
          if (vf != null && vf.size >= 1024) videosInThisDir.add(vf);
        } else if (entity is Directory) {
          final name = p.basename(entity.path);
          if (!name.startsWith('.')) subDirs.add(entity);
        }
      }

      if (videosInThisDir.isNotEmpty) {
        out[dir.path] = videosInThisDir;
        currentTotal += videosInThisDir.length;
        if (currentTotal % 25 == 0) onProgress?.call(currentTotal);
      }

      for (final sub in subDirs) {
        currentTotal = _recurseForFoldersSync(sub, out, currentTotal, onProgress);
      }
    } catch (_) {}
    return currentTotal;
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
          final name = p.basename(entity.path);
          if (!name.startsWith('.')) dirs.add(entity);
        } else if (entity is File && VideoFile.isVideoFile(entity.path)) {
          final vf = VideoFile.fromFile(entity);
          if (vf != null && vf.size >= 1024) videos.add(vf);
        }
      }
    } catch (_) {}

    // Precompute sort keys — p.basename is cheaper than split().last
    // and both are computed once rather than O(n log n) times.
    final dkeys = {for (final d in dirs) d: p.basename(d.path).toLowerCase()};
    dirs.sort((a, b) => dkeys[a]!.compareTo(dkeys[b]!));
    final vkeys2 = {for (final v in videos) v: v.name.toLowerCase()};
    videos.sort((a, b) => vkeys2[a]!.compareTo(vkeys2[b]!));

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
