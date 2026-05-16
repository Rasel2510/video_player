import '../entities/video_entity.dart';
import '../repositories/recent_repository.dart';

class AddRecentUseCase {
  const AddRecentUseCase(this._repo);
  final RecentRepository _repo;

  Future<void> call(VideoEntity video) => _repo.addRecent(video);
}
