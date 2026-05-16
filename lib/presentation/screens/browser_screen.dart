import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import '../../domain/entities/video_entity.dart';
import '../providers/browser_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/folder_tile.dart';
import '../widgets/video_tile.dart';

class BrowserScreen extends ConsumerWidget {
  final void Function(VideoEntity) onOpenVideo;

  const BrowserScreen({super.key, required this.onOpenVideo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(browserProvider);
    final notifier = ref.read(browserProvider.notifier);

    if (!state.hasRoot) {
      return EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'Browse your device',
        subtitle: 'Navigate directories to find videos',
        actionLabel: 'CHOOSE ROOT FOLDER',
        onAction: notifier.pickRoot,
      );
    }

    return Column(
      children: [
        _BreadcrumbBar(
          breadcrumbs: state.breadcrumbs,
          onNavigateToBreadcrumb: notifier.navigateToBreadcrumb,
          onNavigateUp: state.breadcrumbs.length > 1 ? notifier.navigateUp : null,
          onChangeRoot: notifier.pickRoot,
        ),
        Expanded(
          child: state.contents.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
            data: (contents) {
              if (contents.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_off_outlined,
                          size: 36, color: AppColors.border),
                      SizedBox(height: 12),
                      Text('Empty folder',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
                );
              }

              final dirs = contents.subDirectories;
              final videos = contents.videos;
              final showDivider = dirs.isNotEmpty && videos.isNotEmpty;
              final totalItems =
                  dirs.length + videos.length + (showDivider ? 1 : 0);

              return ListView.builder(
                itemCount: totalItems,
                itemBuilder: (_, i) {
                  // Directories
                  if (i < dirs.length) {
                    return FolderTile(
                      dirPath: dirs[i],
                      onTap: () => notifier.navigateTo(dirs[i]),
                    );
                  }
                  // Divider
                  if (showDivider && i == dirs.length) {
                    return _SectionLabel(
                        label: '${videos.length} VIDEO${videos.length == 1 ? '' : 'S'}');
                  }
                  // Videos
                  final vi = showDivider ? i - dirs.length - 1 : i - dirs.length;
                  return VideoTile(
                    video: videos[vi],
                    onTap: () => onOpenVideo(videos[vi]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _BreadcrumbBar extends StatelessWidget {
  final List<String> breadcrumbs;
  final void Function(int) onNavigateToBreadcrumb;
  final VoidCallback? onNavigateUp;
  final VoidCallback onChangeRoot;

  const _BreadcrumbBar({
    required this.breadcrumbs,
    required this.onNavigateToBreadcrumb,
    required this.onNavigateUp,
    required this.onChangeRoot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          if (onNavigateUp != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  size: 15, color: AppColors.textSecondary),
              onPressed: onNavigateUp,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: breadcrumbs.length,
              separatorBuilder: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right,
                    size: 14, color: AppColors.textDim),
              ),
              itemBuilder: (_, i) {
                final isLast = i == breadcrumbs.length - 1;
                final name = p.basename(breadcrumbs[i]).isEmpty
                    ? breadcrumbs[i]
                    : p.basename(breadcrumbs[i]);
                return Center(
                  child: GestureDetector(
                    onTap: isLast ? null : () => onNavigateToBreadcrumb(i),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color:
                            isLast ? AppColors.accent : AppColors.textMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.drive_folder_upload_outlined,
                size: 18, color: AppColors.textMuted),
            tooltip: 'Change root folder',
            onPressed: onChangeRoot,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label,
              style: AppTextStyles.bodySmall.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 2,
              )),
        ),
      );
}
