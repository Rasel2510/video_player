import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/duration_formatter.dart';
import '../models/video_file.dart';
import '../models/video_folder.dart';
import '../presentation/providers/folders_provider.dart';

import '../services/position_service.dart';
import '../services/recent_files_service.dart';
import 'folder_videos_screen.dart';
import 'player_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  final void Function(VideoFile) onOpenVideo;
  const LibraryScreen({super.key, required this.onOpenVideo});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  bool _permissionGranted = false;
  bool _checkingPermission = true;
  final Map<String, _FolderResume?> _folderResumes = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsAndLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed && _permissionGranted) {
      ref.read(foldersProvider.notifier).load(forceScan: false);
    }
  }

  Future<void> _checkPermissionsAndLoad() async {
    setState(() => _checkingPermission = true);
    final results = await Future.wait([
      Permission.manageExternalStorage.request(),
      Permission.storage.request(),
      Permission.videos.request(),
    ]);
    final granted = results.any((s) => s.isGranted);
    if (!mounted) return;
    setState(() {
      _permissionGranted = granted;
      _checkingPermission = false;
    });
    if (granted) ref.read(foldersProvider.notifier).load(forceScan: false);
  }

  Future<void> _loadFolderResumes(List<VideoFolder> folders) async {
    for (final folder in folders) {
      if (_folderResumes.containsKey(folder.path)) continue;
      final resume = await _findLastWatched(folder);
      if (mounted) setState(() => _folderResumes[folder.path] = resume);
    }
  }

  Future<_FolderResume?> _findLastWatched(VideoFolder folder) async {
    VideoFile? best;
    Duration? bestPos;
    for (final vf in folder.videos) {
      final pos = await PositionService.instance.load(vf.path);
      if (pos != null && pos > Duration.zero) {
        if (best == null || vf.modified.isAfter(best.modified)) {
          best = vf;
          bestPos = pos;
        }
      }
    }
    return best != null ? _FolderResume(best, bestPos!) : null;
  }

  void _openFolder(VideoFolder folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => FolderVideosScreen(folder: folder)),
    ).then((_) {
      if (mounted) {
        setState(() => _folderResumes.remove(folder.path));
        _findLastWatched(folder).then((r) {
          if (mounted) setState(() => _folderResumes[folder.path] = r);
        });
      }
    });
  }

  Future<void> _resumeFolder(VideoFolder folder, _FolderResume resume) async {
    await RecentFilesService.addRecent(resume.video);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          filePath: resume.video.path,
          fileName: resume.video.name,
          resumeFrom: resume.position,
          folderVideos: folder.videos,
          initialIndex: folder.videos.indexOf(resume.video),
        ),
      ),
    );
    if (mounted) {
      setState(() => _folderResumes.remove(folder.path));
      _findLastWatched(folder)
          .then((r) {
        if (mounted) setState(() => _folderResumes[folder.path] = r);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_checkingPermission) {
      return const Center(
          child: CircularProgressIndicator());
    }
    if (!_permissionGranted) {
      return _PermissionPrompt(onRetry: _checkPermissionsAndLoad);
    }

    final state = ref.watch(foldersProvider);

    if (state.isScanning && state.folders.isEmpty) {
      return _ScanningScreen(
          progress: state.scanProgress,
          storageCount: state.storageRoots.length);
    }
    if (!state.isScanning && state.folders.isEmpty) {
      return _EmptyLibrary(
          onScan: () =>
              ref.read(foldersProvider.notifier).load(forceScan: true));
    }

    final folders = state.folders;
    final hasMultiStorage = state.storageRoots.length > 1;
    _loadFolderResumes(folders);

    return Column(
      children: [
        _LibraryHeader(
          folderCount: folders.length,
          storageCount: hasMultiStorage ? state.storageRoots.length : null,
          isScanning: state.isScanning,
          fromCache: state.fromCache,
          onRescan: state.isScanning
              ? null
              : () =>
                  ref.read(foldersProvider.notifier).load(forceScan: true),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: folders.length,
            itemBuilder: (_, i) {
              final folder = folders[i];
              final resume = _folderResumes[folder.path];
              final isExternal =
                  hasMultiStorage && !folder.path.contains('/emulated/');
              return _FolderCard(
                folder: folder,
                isExternal: isExternal,
                resume: resume,
                onTap: () => _openFolder(folder),
                onResume: resume != null
                    ? () => _resumeFolder(folder, resume)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────

class _FolderResume {
  final VideoFile video;
  final Duration position;
  const _FolderResume(this.video, this.position);
}

// ── Folder card ───────────────────────────────────────────────────────────────

class _FolderCard extends StatelessWidget {
  final VideoFolder folder;
  final bool isExternal;
  final _FolderResume? resume;
  final VoidCallback onTap;
  final VoidCallback? onResume;

  const _FolderCard({
    required this.folder,
    required this.isExternal,
    required this.onTap,
    this.resume,
    this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.md,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.accentSoft,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Folder icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isExternal
                        ? const Color(0xFF0F2020)
                        : AppColors.folderTint,
                    borderRadius: AppRadius.sm,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.folder_rounded,
                        size: 26,
                        color: isExternal
                            ? const Color(0xFF40AAAA)
                            : AppColors.folderIcon,
                      ),
                      if (isExternal)
                        const Positioned(
                          right: 4,
                          bottom: 4,
                          child: Icon(Icons.sd_card_rounded,
                              size: 10,
                              color: Color(0xFF40AAAA)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Name + count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '${folder.videoCount} '
                            'video${folder.videoCount == 1 ? '' : 's'}',
                            style: AppTextStyles.bodySmall,
                          ),
                          if (isExternal) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0A2020),
                                borderRadius: AppRadius.xs,
                              ),
                              child: const Text('SD',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF40AAAA),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Resume pill
                if (onResume != null && resume != null) ...[
                  _ResumePill(
                    position: resume!.position,
                    onTap: onResume!,
                  ),
                  const SizedBox(width: 10),
                ],

                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Resume pill inside folder card ───────────────────────────────────────────

class _ResumePill extends StatelessWidget {
  final Duration position;
  final VoidCallback onTap;
  const _ResumePill({required this.position, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accentSoft,
          borderRadius: AppRadius.xl,
          border: Border.all(color: AppColors.accentGlow, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded,
                size: 13, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(
              DurationFormatter.format(position),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Library header ────────────────────────────────────────────────────────────

class _LibraryHeader extends StatelessWidget {
  final int folderCount;
  final int? storageCount;
  final bool isScanning;
  final bool fromCache;
  final VoidCallback? onRescan;

  const _LibraryHeader({
    required this.folderCount,
    required this.isScanning,
    required this.fromCache,
    required this.onRescan,
    this.storageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
      child: Row(
        children: [
          Text(
            '$folderCount folder${folderCount == 1 ? '' : 's'}',
            style: AppTextStyles.label,
          ),
          if (storageCount != null) ...[
            const SizedBox(width: 8),
            Text('· $storageCount storages',
                style: AppTextStyles.caption),
          ],
          const Spacer(),
          if (isScanning)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          if (fromCache && !isScanning)
            const Text('cached', style: AppTextStyles.caption),
          TextButton(
            onPressed: onRescan,
            child: Text(
              'Rescan',
              style: TextStyle(
                fontSize: 12,
                color: isScanning
                    ? AppColors.textMuted
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-screens ───────────────────────────────────────────────────────────────

class _PermissionPrompt extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionPrompt({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _CenteredPrompt(
      icon: Icons.lock_outline_rounded,
      title: 'Storage access needed',
      subtitle: 'Grant permission to scan your device for videos',
      action: _PrimaryButton(label: 'Grant Permission', onTap: onRetry),
    );
  }
}

class _ScanningScreen extends StatelessWidget {
  final int progress;
  final int storageCount;
  const _ScanningScreen(
      {required this.progress, required this.storageCount});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 24),
          Text('Scanning device…',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text('$progress videos found', style: AppTextStyles.caption),
          if (storageCount > 1) ...[
            const SizedBox(height: 4),
            Text('$storageCount storages',
                style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyLibrary({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return _CenteredPrompt(
      icon: Icons.video_library_outlined,
      title: 'No videos found',
      subtitle: 'Tap below to scan your device',
      action: _PrimaryButton(label: 'Scan now', onTap: onScan),
    );
  }
}

class _CenteredPrompt extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget action;

  const _CenteredPrompt({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            action,
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        padding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        textStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}
