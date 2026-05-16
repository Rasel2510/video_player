import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/recent_local_datasource.dart';
import '../../data/datasources/video_local_datasource.dart';
import '../../data/repositories/recent_repository_impl.dart';
import '../../data/repositories/video_repository_impl.dart';
import '../../domain/repositories/recent_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../../domain/usecases/add_recent_usecase.dart';
import '../../domain/usecases/clear_recents_usecase.dart';
import '../../domain/usecases/get_recents_usecase.dart';
import '../../domain/usecases/list_directory_usecase.dart';
import '../../domain/usecases/pick_directory_usecase.dart';
import '../../domain/usecases/pick_video_usecase.dart';
import '../../domain/usecases/remove_recent_usecase.dart';
import '../../domain/usecases/scan_directory_usecase.dart';

// ── Data Sources ──────────────────────────────────────────────────────────────

final videoLocalDataSourceProvider = Provider<VideoLocalDataSource>(
  (_) => VideoLocalDataSource(),
);

final recentLocalDataSourceProvider = Provider<RecentLocalDataSource>(
  (_) => RecentLocalDataSource(),
);

// ── Repositories ──────────────────────────────────────────────────────────────

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  return VideoRepositoryImpl(ref.watch(videoLocalDataSourceProvider));
});

final recentRepositoryProvider = Provider<RecentRepository>((ref) {
  return RecentRepositoryImpl(ref.watch(recentLocalDataSourceProvider));
});

// ── Use Cases ─────────────────────────────────────────────────────────────────

final getRecentsUseCaseProvider = Provider<GetRecentsUseCase>(
  (ref) => GetRecentsUseCase(ref.watch(recentRepositoryProvider)),
);

final addRecentUseCaseProvider = Provider<AddRecentUseCase>(
  (ref) => AddRecentUseCase(ref.watch(recentRepositoryProvider)),
);

final removeRecentUseCaseProvider = Provider<RemoveRecentUseCase>(
  (ref) => RemoveRecentUseCase(ref.watch(recentRepositoryProvider)),
);

final clearRecentsUseCaseProvider = Provider<ClearRecentsUseCase>(
  (ref) => ClearRecentsUseCase(ref.watch(recentRepositoryProvider)),
);

final pickVideoUseCaseProvider = Provider<PickVideoUseCase>(
  (ref) => PickVideoUseCase(ref.watch(videoRepositoryProvider)),
);

final pickDirectoryUseCaseProvider = Provider<PickDirectoryUseCase>(
  (ref) => PickDirectoryUseCase(ref.watch(videoRepositoryProvider)),
);

final listDirectoryUseCaseProvider = Provider<ListDirectoryUseCase>(
  (ref) => ListDirectoryUseCase(ref.watch(videoRepositoryProvider)),
);

final scanDirectoryUseCaseProvider = Provider<ScanDirectoryUseCase>(
  (ref) => ScanDirectoryUseCase(ref.watch(videoRepositoryProvider)),
);
