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
  bool _awaitingStorageSettings = false;

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _searchOpen = false;

  final Map<String, _FolderResume?> _folderResumes = {};
  List<VideoFolder>? _lastFoldersLoaded;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
    _checkPermissionsAndLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed) return;
    if (_permissionGranted) {
      ref.read(foldersProvider.notifier).load(forceScan: false);
    } else if (_awaitingStorageSettings) {
      _awaitingStorageSettings = false;
      _recheckPermissionsAfterSettings();
    }
  }

  // ── Permission helpers ────────────────────────────────────────────────────

  Future<void> _checkPermissionsAndLoad() async {
    setState(() => _checkingPermission = true);
    await Permission.videos.request();
    if (!mounted) return;
    await Permission.storage.request();
    if (!mounted) return;
    await Permission.notification.request();
    if (!mounted) return;
    final manageStatus = await Permission.manageExternalStorage.status;
    if (!manageStatus.isGranted) {
      _awaitingStorageSettings = true;
      await Permission.manageExternalStorage.request();
      if (!mounted) return;
      _awaitingStorageSettings = false;
    }
    await _applyPermissionResult();
  }

  Future<void> _recheckPermissionsAfterSettings() async {
    if (_checkingPermission) return;
    final results = await Future.wait([
      Permission.manageExternalStorage.isGranted,
      Permission.storage.isGranted,
      Permission.videos.isGranted,
    ]);
    if (!mounted) return;
    if (results.any((g) => g) && !_permissionGranted) {
      setState(() => _permissionGranted = true);
      ref.read(foldersProvider.notifier).load(forceScan: false);
    }
  }

  Future<void> _applyPermissionResult() async {
    final results = await Future.wait([
      Permission.manageExternalStorage.isGranted,
      Permission.storage.isGranted,
      Permission.videos.isGranted,
    ]);
    if (!mounted) return;
    final granted = results.any((g) => g);
    setState(() {
      _permissionGranted = granted;
      _checkingPermission = false;
    });
    if (granted) ref.read(foldersProvider.notifier).load(forceScan: false);
  }

  // ── Folder resume helpers ──────────────────────────────────────────────────

  Future<void> _loadFolderResumes(List<VideoFolder> folders) async {
    final futures = folders
        .where((f) => !_folderResumes.containsKey(f.path))
        .map((folder) async {
      final resume = await _findLastWatched(folder);
      return (folder.path, resume);
    });
    final results = await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      for (final (path, resume) in results) {
        _folderResumes[path] = resume;
      }
    });
  }

  Future<_FolderResume?> _findLastWatched(VideoFolder folder) async {
    final futures = folder.videos.map((vf) async {
      final pos = await PositionService.instance.load(vf.path);
      return (vf, pos);
    });
    final results = await Future.wait(futures);
    VideoFile? best;
    Duration? bestPos;
    for (final (vf, pos) in results) {
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
      MaterialPageRoute(builder: (_) => FolderVideosScreen(folder: folder)),
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
      _findLastWatched(folder).then((r) {
        if (mounted) setState(() => _folderResumes[folder.path] = r);
      });
    }
  }

  // ── Search helpers ─────────────────────────────────────────────────────────

  List<VideoFolder> _filtered(List<VideoFolder> folders) {
    if (_searchQuery.isEmpty) return folders;
    return folders
        .where((f) => f.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchCtrl.clear();
        _searchQuery = '';
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_checkingPermission) {
      return const Center(child: CircularProgressIndicator());
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

    final allFolders = state.folders;
    final hasMultiStorage = state.storageRoots.length > 1;

    if (!identical(_lastFoldersLoaded, allFolders)) {
      _lastFoldersLoaded = allFolders;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadFolderResumes(allFolders);
      });
    }

    final displayFolders = _filtered(allFolders);

    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        _LibraryHeader(
          folderCount: allFolders.length,
          filteredCount: _searchQuery.isNotEmpty ? displayFolders.length : null,
          storageCount: hasMultiStorage ? state.storageRoots.length : null,
          isScanning: state.isScanning,
          fromCache: state.fromCache,
          searchOpen: _searchOpen,
          searchCtrl: _searchCtrl,
          onToggleSearch: _toggleSearch,
          onRescan: state.isScanning
              ? null
              : () => ref.read(foldersProvider.notifier).load(forceScan: true),
        ),

        // ── Folder list with pull-to-refresh ────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(foldersProvider.notifier).load(forceScan: true),
            color: context.colors.accent,
            backgroundColor: context.colors.surface,
            child: displayFolders.isEmpty
                ? _NoResults(query: _searchQuery)
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: displayFolders.length,
                    itemBuilder: (_, i) {
                      final folder = displayFolders[i];
                      final resume = _folderResumes[folder.path];
                      final isExternal = hasMultiStorage &&
                          !folder.path.contains('/emulated/');
                      final isNew = ref
                          .watch(foldersProvider.select((s) => s.newPaths))
                          .contains(folder.path);
                      return _FolderCard(
                        folder: folder,
                        isExternal: isExternal,
                        isNew: isNew,
                        resume: resume,
                        onTap: () => _openFolder(folder),
                        onResume: resume != null
                            ? () => _resumeFolder(folder, resume)
                            : null,
                      );
                    },
                  ),
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

// ── Library header ────────────────────────────────────────────────────────────

class _LibraryHeader extends StatelessWidget {
  final int folderCount;
  final int? filteredCount;
  final int? storageCount;
  final bool isScanning;
  final bool fromCache;
  final bool searchOpen;
  final TextEditingController searchCtrl;
  final VoidCallback onToggleSearch;
  final VoidCallback? onRescan;

  const _LibraryHeader({
    required this.folderCount,
    required this.isScanning,
    required this.fromCache,
    required this.searchOpen,
    required this.searchCtrl,
    required this.onToggleSearch,
    required this.onRescan,
    this.filteredCount,
    this.storageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
          child: Row(
            children: [
              if (filteredCount != null)
                Text(
                  '$filteredCount of $folderCount folder${folderCount == 1 ? '' : 's'}',
                  style: context.textStyles.label,
                )
              else
                Text(
                  '$folderCount folder${folderCount == 1 ? '' : 's'}',
                  style: context.textStyles.label,
                ),
              if (storageCount != null) ...[
                const SizedBox(width: 8),
                Text('· $storageCount storages',
                    style: context.textStyles.caption),
              ],
              const Spacer(),
              if (isScanning)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              if (fromCache && !isScanning)
                Text('cached', style: context.textStyles.caption),
              // Search toggle
              IconButton(
                icon: Icon(
                  searchOpen ? Icons.search_off_rounded : Icons.search_rounded,
                  size: 20,
                  color: searchOpen
                      ? context.colors.accent
                      : context.colors.textSecondary,
                ),
                onPressed: onToggleSearch,
                tooltip: searchOpen ? 'Close search' : 'Search folders',
                visualDensity: VisualDensity.compact,
              ),
              TextButton(
                onPressed: onRescan,
                child: Text(
                  'Rescan',
                  style: TextStyle(
                    fontSize: 12,
                    color: isScanning
                        ? context.colors.textMuted
                        : context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Animated search bar
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: searchOpen
              ? Padding(
                  key: const ValueKey('search'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                        color: context.colors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search folders…',
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 18, color: context.colors.textMuted),
                      suffixIcon: searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded,
                                  size: 16, color: context.colors.textMuted),
                              onPressed: searchCtrl.clear,
                            )
                          : null,
                    ),
                  ),
                )
              : const SizedBox(key: ValueKey('no-search'), height: 0),
        ),
      ],
    );
  }
}

// ── No results ────────────────────────────────────────────────────────────────

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.search_off_rounded,
                    size: 40, color: context.colors.textMuted),
                SizedBox(height: 14),
                Text(
                  'No folders match "$query"',
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Folder card ───────────────────────────────────────────────────────────────

class _FolderCard extends StatelessWidget {
  final VideoFolder folder;
  final bool isExternal;
  final bool isNew;
  final _FolderResume? resume;
  final VoidCallback onTap;
  final VoidCallback? onResume;

  const _FolderCard({
    required this.folder,
    required this.isExternal,
    required this.onTap,
    this.isNew = false,
    this.resume,
    this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.colors.surface,
        borderRadius: AppRadius.md,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: context.colors.accentSoft,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.folder_rounded,
                      size: 32,
                      color: isExternal
                          ? const Color(0xFF40AAAA)
                          : context.colors.folderIcon,
                    ),
                    if (isExternal)
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: Icon(Icons.sd_card_rounded,
                            size: 10, color: Color(0xFF40AAAA)),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isNew) ...[
                        const SizedBox(height: 2),
                        const _NewBadge(),
                      ],
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '${folder.videoCount} '
                            'video${folder.videoCount == 1 ? '' : 's'}',
                            style: context.textStyles.bodySmall,
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
                if (onResume != null && resume != null) ...[
                  _ResumePill(position: resume!.position, onTap: onResume!),
                  SizedBox(width: 10),
                ],
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: context.colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Resume pill ───────────────────────────────────────────────────────────────

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
          color: context.colors.accentSoft,
          borderRadius: AppRadius.xl,
          border: Border.all(color: context.colors.accentGlow, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded,
                size: 13, color: context.colors.accent),
            SizedBox(width: 4),
            Text(
              DurationFormatter.format(position),
              style: TextStyle(
                fontSize: 10,
                color: context.colors.accent,
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

// ── Sub-screens ───────────────────────────────────────────────────────────────

class _PermissionPrompt extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionPrompt({required this.onRetry});

  @override
  Widget build(BuildContext context) => _CenteredPrompt(
        icon: Icons.lock_outline_rounded,
        title: 'Storage access needed',
        subtitle: 'Grant permission to scan your device for videos',
        action: _PrimaryButton(label: 'Grant Permission', onTap: onRetry),
      );
}

class _ScanningScreen extends StatelessWidget {
  final int progress;
  final int storageCount;
  const _ScanningScreen({required this.progress, required this.storageCount});

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
              style: context.textStyles.body
                  .copyWith(color: context.colors.textSecondary)),
          const SizedBox(height: 6),
          Text('$progress videos found', style: context.textStyles.caption),
          if (storageCount > 1) ...[
            const SizedBox(height: 4),
            Text('$storageCount storages', style: context.textStyles.caption),
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
  Widget build(BuildContext context) => _CenteredPrompt(
        icon: Icons.video_library_outlined,
        title: 'No videos found',
        subtitle: 'Pull down to refresh, or tap below to scan',
        action: _PrimaryButton(label: 'Scan now', onTap: onScan),
      );
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
              decoration: BoxDecoration(
                  color: context.colors.surface, shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: context.colors.textMuted),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary)),
            SizedBox(height: 6),
            Text(subtitle,
                style: context.textStyles.bodySmall,
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
        backgroundColor: context.colors.accent,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

// ── NEW badge ─────────────────────────────────────────────────────────────────

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.accentSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.colors.accentGlow, width: 1),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: context.colors.accent,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}