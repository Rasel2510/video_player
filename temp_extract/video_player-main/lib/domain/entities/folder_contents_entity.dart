import 'video_entity.dart';

class FolderContentsEntity {
  final List<String> subDirectories;
  final List<VideoEntity> videos;

  const FolderContentsEntity({
    required this.subDirectories,
    required this.videos,
  });

  bool get isEmpty => subDirectories.isEmpty && videos.isEmpty;
}
