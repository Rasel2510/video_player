import '../repositories/recent_repository.dart';

class ClearRecentsUseCase {
  const ClearRecentsUseCase(this._repo);
  final RecentRepository _repo;

  Future<void> call() => _repo.clearAll();
}
