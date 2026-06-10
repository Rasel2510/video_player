import '../repositories/recent_repository.dart';

class RemoveRecentUseCase {
  const RemoveRecentUseCase(this._repo);
  final RecentRepository _repo;

  Future<void> call(String path) => _repo.removeRecent(path);
}
