import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/video_entity.dart';
import 'dependency_providers.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class LibraryState {
  final String? scanPath;
  final List<VideoEntity> videos;
  final bool isScanning;
  final int scanProgress;
  final String searchQuery;

  const LibraryState({
    this.scanPath,
    this.videos = const [],
    this.isScanning = false,
    this.scanProgress = 0,
    this.searchQuery = '',
  });

  List<VideoEntity> get filtered {
    if (searchQuery.isEmpty) return videos;
    return videos
        .where(
            (v) => v.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  LibraryState copyWith({
    String? scanPath,
    List<VideoEntity>? videos,
    bool? isScanning,
    int? scanProgress,
    String? searchQuery,
  }) =>
      LibraryState(
        scanPath: scanPath ?? this.scanPath,
        videos: videos ?? this.videos,
        isScanning: isScanning ?? this.isScanning,
        scanProgress: scanProgress ?? this.scanProgress,
        searchQuery: searchQuery ?? this.searchQuery,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class LibraryNotifier extends Notifier<LibraryState> {
  @override
  LibraryState build() => const LibraryState();

  Future<void> pickAndScan() async {
    final path = await ref.read(pickDirectoryUseCaseProvider).call();
    if (path == null) return;

    state = LibraryState(scanPath: path, isScanning: true);

    final videos = <VideoEntity>[];
    await for (final video
        in ref.read(scanDirectoryUseCaseProvider).call(path)) {
      videos.add(video);
      state = state.copyWith(scanProgress: videos.length);
    }

    videos.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = state.copyWith(videos: videos, isScanning: false);
  }

  void updateSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(
  LibraryNotifier.new,
);
