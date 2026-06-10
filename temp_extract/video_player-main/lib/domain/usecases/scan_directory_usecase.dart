import '../entities/video_entity.dart';
import '../repositories/video_repository.dart';

class ScanDirectoryUseCase {
  const ScanDirectoryUseCase(this._repo);
  final VideoRepository _repo;

  Stream<VideoEntity> call(String path) => _repo.scanDirectory(path);
}
