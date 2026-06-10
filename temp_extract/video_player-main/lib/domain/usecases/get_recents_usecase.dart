import '../entities/video_entity.dart';
import '../repositories/recent_repository.dart';

class GetRecentsUseCase {
  const GetRecentsUseCase(this._repo);
  final RecentRepository _repo;

  Future<List<VideoEntity>> call() => _repo.getRecents();
}
