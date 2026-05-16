import '../entities/folder_contents_entity.dart';
import '../repositories/video_repository.dart';

class ListDirectoryUseCase {
  const ListDirectoryUseCase(this._repo);
  final VideoRepository _repo;

  Future<FolderContentsEntity> call(String path) => _repo.listDirectory(path);
}
