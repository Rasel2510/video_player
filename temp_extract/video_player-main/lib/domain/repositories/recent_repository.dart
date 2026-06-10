import '../entities/video_entity.dart';

abstract interface class RecentRepository {
  Future<List<VideoEntity>> getRecents();
  Future<void> addRecent(VideoEntity video);
  Future<void> removeRecent(String path);
  Future<void> clearAll();
}
