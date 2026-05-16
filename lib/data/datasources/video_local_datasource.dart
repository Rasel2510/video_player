import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../domain/entities/folder_contents_entity.dart';
import '../../domain/entities/video_entity.dart';

class VideoLocalDataSource {
  Future<VideoEntity?> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return null;
    final f = result.files.single;
    return VideoEntity(
      path: f.path!,
      name: f.name,
      sizeBytes: f.size,
      lastModified: DateTime.now(),
    );
  }

  Future<String?> pickDirectory() =>
      FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose folder');

  Future<FolderContentsEntity> listDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return const FolderContentsEntity(subDirectories: [], videos: []);
    }

    final dirs = <String>[];
    final videos = <VideoEntity>[];

    try {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
          if (!name.startsWith('.')) dirs.add(entity.path);
        } else if (entity is File && VideoEntity.isVideoPath(entity.path)) {
          final v = _fileToEntity(entity);
          if (v != null) videos.add(v);
        }
      }
    } catch (_) {}

    dirs.sort((a, b) =>
        p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()));
    videos.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return FolderContentsEntity(subDirectories: dirs, videos: videos);
  }

  Stream<VideoEntity> scanDirectory(String dirPath) async* {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return;
    yield* _scanRecursive(dir);
  }

  Stream<VideoEntity> _scanRecursive(Directory dir) async* {
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && VideoEntity.isVideoPath(entity.path)) {
          final v = _fileToEntity(entity);
          if (v != null) yield v;
        } else if (entity is Directory) {
          yield* _scanRecursive(entity);
        }
      }
    } catch (_) {}
  }

  VideoEntity? _fileToEntity(File file) {
    try {
      final stat = file.statSync();
      return VideoEntity(
        path: file.path,
        name: p.basename(file.path),
        sizeBytes: stat.size,
        lastModified: stat.modified,
      );
    } catch (_) {
      return null;
    }
  }
}
