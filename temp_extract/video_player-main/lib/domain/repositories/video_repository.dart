import '../entities/folder_contents_entity.dart';
import '../entities/video_entity.dart';

abstract interface class VideoRepository {
  /// Pick a single video file via system picker.
  Future<VideoEntity?> pickVideo();

  /// Pick a root directory via system picker.
  Future<String?> pickDirectory();

  /// List contents of [dirPath] (non-recursive).
  Future<FolderContentsEntity> listDirectory(String dirPath);

  /// Recursively scan [dirPath] for all video files.
  Stream<VideoEntity> scanDirectory(String dirPath);
}
