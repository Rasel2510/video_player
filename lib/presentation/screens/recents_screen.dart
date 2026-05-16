import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/video_entity.dart';
import '../providers/recents_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/recent_tile.dart';

class RecentsScreen extends ConsumerWidget {
  final void Function(VideoEntity) onOpenVideo;
  final VoidCallback onPickFile;

  const RecentsScreen({
    super.key,
    required this.onOpenVideo,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRecents = ref.watch(recentsProvider);

    return asyncRecents.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: AppColors.textSecondary)),
      ),
      data: (recents) {
        if (recents.isEmpty) {
          return EmptyState(
            icon: Icons.history,
            title: 'No recent videos',
            subtitle: 'Videos you play will appear here',
            actionLabel: 'OPEN A VIDEO',
            onAction: onPickFile,
          );
        }

        return Column(
          children: [
            _RecentsHeader(
              count: recents.length,
              onClearAll: () => _confirmClear(context, ref),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: recents.length,
                itemBuilder: (_, i) {
                  final video = recents[i];
                  return Dismissible(
                    key: Key(video.path),
                    direction: DismissDirection.endToStart,
                    background: const _DismissBackground(),
                    onDismissed: (_) =>
                        ref.read(recentsProvider.notifier).remove(video.path),
                    child: RecentTile(
                      video: video,
                      onTap: () => onOpenVideo(video),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ClearDialog(),
    );
    if (ok == true) ref.read(recentsProvider.notifier).clearAll();
  }
}

class _RecentsHeader extends StatelessWidget {
  final int count;
  final VoidCallback onClearAll;

  const _RecentsHeader({required this.count, required this.onClearAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Row(
        children: [
          Text(
            '$count VIDEO${count == 1 ? '' : 'S'}',
            style: AppTextStyles.bodySmall.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onClearAll,
            child: Text('CLEAR ALL', style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.errorBg,
        child: const Icon(Icons.delete_outline,
            color: AppColors.errorRed, size: 22),
      );
}

class _ClearDialog extends StatelessWidget {
  const _ClearDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Clear history?',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      );
}
