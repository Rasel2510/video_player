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
    // Cache the lowercased query — avoids re-lowercasing it for every element.
    final q = searchQuery.toLowerCase();
    return videos.where((v) => v.name.toLowerCase().contains(q)).toList();
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

    // Precompute keys — for a large scan result this avoids O(n log n)
    // toLowerCase allocations inside the comparator.
    final keys = {for (final v in videos) v: v.name.toLowerCase()};
    videos.sort((a, b) => keys[a]!.compareTo(keys[b]!));
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
