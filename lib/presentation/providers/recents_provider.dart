import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/video_entity.dart';
import 'dependency_providers.dart';

class RecentsNotifier extends AsyncNotifier<List<VideoEntity>> {
  @override
  Future<List<VideoEntity>> build() =>
      ref.read(getRecentsUseCaseProvider).call();

  Future<void> add(VideoEntity video) async {
    await ref.read(addRecentUseCaseProvider).call(video);
    ref.invalidateSelf();
  }

  Future<void> remove(String path) async {
    await ref.read(removeRecentUseCaseProvider).call(path);
    ref.invalidateSelf();
  }

  Future<void> clearAll() async {
    await ref.read(clearRecentsUseCaseProvider).call();
    ref.invalidateSelf();
  }
}

final recentsProvider =
    AsyncNotifierProvider<RecentsNotifier, List<VideoEntity>>(
  RecentsNotifier.new,
);
