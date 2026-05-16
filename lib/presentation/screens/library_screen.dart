import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import '../../domain/entities/video_entity.dart';
import '../providers/library_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/video_tile.dart';

class LibraryScreen extends ConsumerWidget {
  final void Function(VideoEntity) onOpenVideo;

  const LibraryScreen({super.key, required this.onOpenVideo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);

    if (state.scanPath == null) {
      return EmptyState(
        icon: Icons.video_library_outlined,
        title: 'Scan a folder for videos',
        subtitle: 'All videos inside will be listed',
        actionLabel: 'CHOOSE FOLDER',
        onAction: notifier.pickAndScan,
      );
    }

    if (state.isScanning) {
      return _ScanningView(progress: state.scanProgress);
    }

    return Column(
      children: [
        _LibraryHeader(
          folderName: p.basename(state.scanPath!).isEmpty
              ? state.scanPath!
              : p.basename(state.scanPath!),
          totalCount: state.videos.length,
          onChangeFolder: notifier.pickAndScan,
        ),
        _SearchBar(
          onChanged: notifier.updateSearch,
          onClear: notifier.clearSearch,
          query: state.searchQuery,
        ),
        if (state.searchQuery.isNotEmpty)
          _ResultCount(count: state.filtered.length),
        Expanded(child: _VideoList(videos: state.filtered, onOpen: onOpenVideo)),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ScanningView extends StatelessWidget {
  final int progress;
  const _ScanningView({required this.progress});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 20),
            Text('SCANNING...', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Text('$progress videos found',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      );
}

class _LibraryHeader extends StatelessWidget {
  final String folderName;
  final int totalCount;
  final VoidCallback onChangeFolder;

  const _LibraryHeader({
    required this.folderName,
    required this.totalCount,
    required this.onChangeFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined,
              size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(folderName,
                style: AppTextStyles.body, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text('$totalCount videos',
              style: AppTextStyles.mono),
          TextButton(
            onPressed: onChangeFolder,
            child: Text('CHANGE', style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final void Function(String) onChanged;
  final VoidCallback onClear;
  final String query;

  const _SearchBar({
    required this.onChanged,
    required this.onClear,
    required this.query,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: TextField(
        controller: _ctrl,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: 'Search videos...',
          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
          suffixIcon: widget.query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                  onPressed: () {
                    _ctrl.clear();
                    widget.onClear();
                  },
                )
              : null,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _ResultCount extends StatelessWidget {
  final int count;
  const _ResultCount({required this.count});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '$count result${count == 1 ? '' : 's'}',
            style: AppTextStyles.mono,
          ),
        ),
      );
}

class _VideoList extends StatelessWidget {
  final List<VideoEntity> videos;
  final void Function(VideoEntity) onOpen;

  const _VideoList({required this.videos, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return const Center(
        child: Text('No videos found',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
      );
    }
    return ListView.builder(
      itemCount: videos.length,
      itemBuilder: (_, i) =>
          VideoTile(video: videos[i], onTap: () => onOpen(videos[i])),
    );
  }
}
