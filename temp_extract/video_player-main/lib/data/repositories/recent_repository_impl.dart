import '../../domain/entities/video_entity.dart';
import '../../domain/repositories/recent_repository.dart';
import '../datasources/recent_local_datasource.dart';

class RecentRepositoryImpl implements RecentRepository {
  const RecentRepositoryImpl(this._dataSource);
  final RecentLocalDataSource _dataSource;

  @override
  Future<List<VideoEntity>> getRecents() => _dataSource.getRecents();

  @override
  Future<void> addRecent(VideoEntity video) => _dataSource.addRecent(video);

  @override
  Future<void> removeRecent(String path) => _dataSource.removeRecent(path);

  @override
  Future<void> clearAll() => _dataSource.clearAll();
}
