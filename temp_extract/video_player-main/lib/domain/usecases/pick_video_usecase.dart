import '../entities/video_entity.dart';
import '../repositories/video_repository.dart';

class PickVideoUseCase {
  const PickVideoUseCase(this._repo);
  final VideoRepository _repo;

  Future<VideoEntity?> call() => _repo.pickVideo();
}
