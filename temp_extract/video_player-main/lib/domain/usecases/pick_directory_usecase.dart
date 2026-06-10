import '../repositories/video_repository.dart';

class PickDirectoryUseCase {
  const PickDirectoryUseCase(this._repo);
  final VideoRepository _repo;

  Future<String?> call() => _repo.pickDirectory();
}
