import '../../domain/entities/folder_contents_entity.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/repositories/video_repository.dart';
import '../datasources/video_local_datasource.dart';

class VideoRepositoryImpl implements VideoRepository {
  const VideoRepositoryImpl(this._dataSource);
  final VideoLocalDataSource _dataSource;

  @override
  Future<VideoEntity?> pickVideo() => _dataSource.pickVideo();

  @override
  Future<String?> pickDirectory() => _dataSource.pickDirectory();

  @override
  Future<FolderContentsEntity> listDirectory(String dirPath) =>
      _dataSource.listDirectory(dirPath);

  @override
  Stream<VideoEntity> scanDirectory(String dirPath) =>
      _dataSource.scanDirectory(dirPath);
}
