import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_video_player/core/theme/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/video_file.dart';
import '../models/video_folder.dart';
import '../presentation/providers/folders_provider.dart';
import '../services/position_service.dart';
import '../services/recent_files_service.dart';
import 'folder_videos_screen.dart';
import '../presentation/widgets/library/empty_library.dart';
import '../presentation/widgets/library/folder_card.dart';
import '../presentation/widgets/library/library_header.dart';
import '../presentation/widgets/library/no_results.dart';
import '../presentation/widgets/library/permission_prompt.dart';
import '../presentation/widgets/library/scanning_screen.dart';
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

  /// FIX #OPT-6: Resume data is now loaded lazily per-folder when each item
  /// becomes visible in the list, rather than eagerly for the entire library
  /// up front.  For a library with 50 folders × 20 videos each, the old
  /// approach fired 1000 SharedPreferences reads before the user saw anything.
  /// Now each folder triggers its own load only once, on first render.
  void _ensureResumeLoaded(VideoFolder folder) {
    if (_folderResumes.containsKey(folder.path)) return;
    // Mark as "in progress" with a sentinel so we don't re-fire on every
    // build frame while the Future is still pending.
    _folderResumes[folder.path] = null;
    _findLastWatched(folder).then((resume) {
      if (mounted) setState(() => _folderResumes[folder.path] = resume);
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
    await RecentFilesService.instance.addRecent(resume.video);
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
      return PermissionPrompt(onRetry: _checkPermissionsAndLoad);
    }

    final state = ref.watch(foldersProvider);

    if (state.isScanning && state.folders.isEmpty) {
      return ScanningScreen(
          progress: state.scanProgress,
          storageCount: state.storageRoots.length);
    }
    if (!state.isScanning && state.folders.isEmpty) {
      return EmptyLibrary(
          onScan: () =>
              ref.read(foldersProvider.notifier).load(forceScan: true));
    }

    final allFolders = state.folders;
    final hasMultiStorage = state.storageRoots.length > 1;

    // _lastFoldersLoaded guard removed — resume data is now loaded lazily
    // inside itemBuilder via _ensureResumeLoaded().

    final displayFolders = _filtered(allFolders);

    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        LibraryHeader(
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
                ? NoResults(query: _searchQuery)
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: displayFolders.length,
                    itemBuilder: (_, i) {
                      final folder     = displayFolders[i];
                      // FIX #OPT-6: trigger resume load the first time this
                      // item scrolls into view rather than loading all at once.
                      _ensureResumeLoaded(folder);
                      final resume     = _folderResumes[folder.path];
                      final isExternal = hasMultiStorage &&
                          !folder.path.contains('/emulated/');
                      // newPaths already watched above — no extra select needed.
                      final isNew = state.newPaths.contains(folder.path);
                      return FolderCard(
                        folder: folder,
                        isExternal: isExternal,
                        isNew: isNew,
                        resumePosition: resume?.position,
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
