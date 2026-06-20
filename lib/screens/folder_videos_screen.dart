import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_video_player/core/theme/app_theme.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../models/video_file.dart';
import '../models/video_folder.dart';
import '../presentation/providers/folders_provider.dart';
import '../presentation/widgets/resume_dialog.dart';
import '../services/duration_cache_service.dart';
import '../services/player_preferences_service.dart';
import '../services/position_service.dart';
import '../services/recent_files_service.dart';
import '../services/thumbnail_service.dart';
import '../core/utils/duration_formatter.dart';
import '../presentation/widgets/folder_videos/no_results.dart';
import '../presentation/widgets/folder_videos/resume_fab.dart';
import '../presentation/widgets/folder_videos/sort_option.dart';
import '../presentation/widgets/folder_videos/sort_sheet.dart';
import '../presentation/widgets/folder_videos/video_card.dart';
import '../presentation/widgets/folder_videos/video_options_sheet.dart';
import 'player_screen.dart';
import '../presentation/widgets/smooth_page_route.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class FolderVideosScreen extends ConsumerStatefulWidget {
  final VideoFolder folder;
  const FolderVideosScreen({super.key, required this.folder});

  @override
  ConsumerState<FolderVideosScreen> createState() => _FolderVideosScreenState();
}

class _FolderVideosScreenState extends ConsumerState<FolderVideosScreen> {
  final Map<String, Duration> _positions = {};
  final Map<String, Duration> _durations = {};
  final Set<String> _deletedPaths = {};
  // Maps a video's original path to its renamed counterpart — widget.folder.videos
  // is a fixed snapshot, so renames are applied here rather than mutating it.
  final Map<String, VideoFile> _renamedOverrides = {};
  bool _positionsLoaded = false;

  // Sort
  SortOption _sortBy = SortOption.name;

  // FIX: cache the sorted list so _sorted() is O(1) on rebuild frames
  // where nothing changed. Invalidated only when sortBy or deletedPaths changes.
  List<VideoFile>? _sortedCache;
  SortOption? _sortedForOption;
  int _sortedDeletedCount = -1;

  // Search inside folder
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _searchOpen = false;

  // Selection
  bool _selectionMode = false;
  final Set<String> _selectedPaths = {};

  void _enterSelectionMode(VideoFile? initialVideo) {
    setState(() {
      _selectionMode = true;
      if (initialVideo != null) {
        _selectedPaths.add(initialVideo.path);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedPaths.clear();
    });
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _selectAll(List<VideoFile> displayedVideos) {
    setState(() {
      final allPaths = displayedVideos.map((v) => v.path).toList();
      if (_selectedPaths.length == allPaths.length) {
        _selectedPaths.clear();
      } else {
        _selectedPaths.addAll(allPaths);
      }
    });
  }

  Future<void> _confirmDeleteSelected(List<VideoFile> displayedVideos) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${_selectedPaths.length} videos?'),
        content: const Text(
          'Selected videos will be permanently removed from your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.errorRed,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final pathsToDelete = _selectedPaths.toList();
    
    // Perform deletions in parallel
    await Future.wait(pathsToDelete.map((path) async {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }));

    // Clean up caches
    await Future.wait(pathsToDelete.map((path) async {
      await Future.wait([
        PositionService.instance.clear(path),
        ThumbnailService.instance.removeThumbnail(path),
        DurationCacheService.instance.removeDuration(path),
      ]);
    }));

    setState(() {
      _deletedPaths.addAll(pathsToDelete);
      for (final path in pathsToDelete) {
        _positions.remove(path);
        _durations.remove(path);
      }
      _sortedCache = null; // force re-sort
    });

    ref.read(foldersProvider.notifier).removeVideos(pathsToDelete);
    _exitSelectionMode();

    // If no videos remain, pop back
    final remaining = widget.folder.videos
        .where((v) => !_deletedPaths.contains(v.path))
        .length;
    if (remaining == 0 && mounted) {
      Navigator.pop(context);
    }
  }

  void _showVideoDetails(VideoFile vf) {
    final dur = _durations[vf.path];
    final durStr = dur != null ? DurationFormatter.format(dur) : 'Unknown';
    final sizeStr = vf.sizeLabel;
    final extension = vf.extensionLabel;
    final dateStr = '${vf.modified.year}-${vf.modified.month.toString().padLeft(2, '0')}-${vf.modified.day.toString().padLeft(2, '0')} '
        '${vf.modified.hour.toString().padLeft(2, '0')}:${vf.modified.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.colors.panel,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(ctx).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: ctx.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: ctx.colors.accent, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Video Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ctx.colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailItem(ctx, 'Name', vf.name),
              _buildDetailItem(ctx, 'Format', extension),
              _buildDetailItem(ctx, 'Size', sizeStr),
              _buildDetailItem(ctx, 'Duration', durStr),
              _buildDetailItem(ctx, 'Date Modified', dateStr),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildDetailItem(ctx, 'Path', vf.path)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, color: ctx.colors.textSecondary, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: vf.path));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Path copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(BuildContext ctx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ctx.colors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: ctx.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() =>
        setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase()));
    _loadSortPreference();
    _loadPositions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSortPreference() async {
    final idx = await PlayerPreferencesService.instance.loadSortByIndex();
    if (!mounted) return;
    setState(() {
      _sortBy = SortOption.values[idx.clamp(0, SortOption.values.length - 1)];
    });
  }

  Future<void> _loadPositions() async {
    final paths = widget.folder.videos.map((v) => v.path).toList();

    // ── Phase 1: instant cache read ───────────────────────────────────────
    // loadCachedDurations does a single SharedPreferences.getInstance() then
    // reads all keys synchronously — typically completes in < 5 ms.
    // Positions are also pure prefs reads so we run both in parallel.
    final results = await Future.wait([
      DurationCacheService.instance.loadCachedDurations(paths),
      Future.wait(paths.map((path) async {
        final pos = await PositionService.instance.load(path);
        return (path, pos ?? Duration.zero);
      })),
    ]);

    if (!mounted) return;
    setState(() {
      final cachedDurs = results[0] as Map<String, Duration>;
      final posList = results[1] as List<(String, Duration)>;
      _durations.addAll(cachedDurs);
      for (final (path, pos) in posList) {
        _positions[path] = pos;
      }
      _positionsLoaded = true;
    });

    // ── Phase 2: background probe for uncached durations ──────────────────
    // Only runs for videos whose duration wasn't in the cache above.
    // Does not block the UI — results trickle in individually.
    final uncached = paths.where((path) => !_durations.containsKey(path)).toList();
    if (uncached.isEmpty) return;

    for (final path in uncached) {
      DurationCacheService.instance.getDuration(path).then((dur) {
        if (!mounted || dur == null) return;
        setState(() => _durations[path] = dur);
      });
    }
  }

  // ── Sorted + filtered video list ──────────────────────────────────────────

  /// FIX: Only recomputes when _sortBy or _deletedPaths.length changes;
  /// returns the cached list on all other build() calls.
  List<VideoFile> _sorted(List<VideoFile> base) {
    if (_sortedCache != null &&
        _sortedForOption == _sortBy &&
        _sortedDeletedCount == _deletedPaths.length) {
      return _sortedCache!;
    }
    final list = base
        .where((v) => !_deletedPaths.contains(v.path))
        .map((v) => _renamedOverrides[v.path] ?? v)
        .toList();
    switch (_sortBy) {
      case SortOption.name:
        // Precompute keys — toLowerCase() in a comparator runs O(n log n) times.
        final nameKeys = {for (final v in list) v: v.name.toLowerCase()};
        list.sort((a, b) => nameKeys[a]!.compareTo(nameKeys[b]!));
      case SortOption.dateModified:
        list.sort((a, b) => b.modified.compareTo(a.modified));
      case SortOption.size:
        list.sort((a, b) => b.size.compareTo(a.size));
      case SortOption.duration:
        list.sort((a, b) {
          final da = _durations[a.path] ?? Duration.zero;
          final db = _durations[b.path] ?? Duration.zero;
          return db.compareTo(da);
        });
    }
    _sortedCache = list;
    _sortedForOption = _sortBy;
    _sortedDeletedCount = _deletedPaths.length;
    return list;
  }

  List<VideoFile> _filtered(List<VideoFile> sorted) {
    if (_searchQuery.isEmpty) return sorted;
    return sorted
        .where((v) => v.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  VideoFile? _lastWatched(List<VideoFile> sorted) {
    if (!_positionsLoaded) return null;
    VideoFile? best;
    for (final vf in sorted) {
      final pos = _positions[vf.path];
      if (pos != null && pos > Duration.zero) {
        if (best == null || vf.modified.isAfter(best.modified)) best = vf;
      }
    }
    return best;
  }

  // ── Open video ─────────────────────────────────────────────────────────────

  Future<void> _openVideo(
    VideoFile vf,
    List<VideoFile> playlist, {
    bool forceResume = false,
  }) async {
    var savedPos = _positions[vf.path];
    final dur = _durations[vf.path];

    // FIX: clear resume position if within last 5 s of known duration.
    if (savedPos != null &&
        savedPos > Duration.zero &&
        dur != null &&
        dur.inMilliseconds > 0) {
      if (dur.inMilliseconds - savedPos.inMilliseconds < 5000) {
        await PositionService.instance.clear(vf.path);
        setState(() => _positions[vf.path] = Duration.zero);
        savedPos = null;
      }
    }

    Duration? resumeFrom;
    if (savedPos != null && savedPos > Duration.zero) {
      if (forceResume) {
        resumeFrom = savedPos;
      } else {
        if (!mounted) return;
        resumeFrom = await ResumeDialog.show(context, savedPos);
        if (resumeFrom == null) return;
      }
    }

    if (!mounted) return;
    await RecentFilesService.instance.addRecent(vf);
    ref.read(foldersProvider.notifier).markSeen(vf.path);
    if (!mounted) return;

    await Navigator.of(context).push(SmoothPageRoute(
      child: PlayerScreen(
        filePath: vf.path,
        fileName: vf.name,
        resumeFrom: resumeFrom,
        folderVideos: playlist,
        initialIndex: playlist.indexOf(vf),
      ),
    ));

    if (mounted) _refreshPosition(vf.path);
  }

  Future<void> _refreshPosition(String path) async {
    // Load position and duration in parallel — they are independent reads.
    final posFuture = PositionService.instance.load(path);
    final durFuture = DurationCacheService.instance.getDuration(path);
    final pos = await posFuture;
    final dur = await durFuture;
    if (!mounted) return;
    setState(() {
      _positions[path] = pos ?? Duration.zero;
      if (dur != null) _durations[path] = dur;
    });
  }

  // ── Long-press options ─────────────────────────────────────────────────────

  void _showVideoOptions(VideoFile vf, List<VideoFile> playlist) {
    // FIX: haptic feedback so the long-press feels deliberate
    HapticFeedback.mediumImpact();

    final hasResume = (_positions[vf.path] ?? Duration.zero) > Duration.zero;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      useSafeArea: true,
      builder: (_) => VideoOptionsSheet(
        vf: vf,
        hasResume: hasResume,
        onPlay: () {
          Navigator.pop(context);
          _openVideo(vf, playlist);
        },
        onShare: () {
          Navigator.pop(context);
          Share.shareXFiles([XFile(vf.path)], text: vf.name);
        },
        onRename: () {
          Navigator.pop(context);
          _showRenameDialog(vf);
        },
        onDetails: () {
          Navigator.pop(context);
          _showVideoDetails(vf);
        },
        onSelect: () {
          Navigator.pop(context);
          _enterSelectionMode(vf);
        },
        onCopyPath: () {
          Navigator.pop(context);
          Clipboard.setData(ClipboardData(text: vf.path));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Path copied to clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        onClearResume: hasResume
            ? () {
                Navigator.pop(context);
                PositionService.instance.clear(vf.path);
                setState(() => _positions[vf.path] = Duration.zero);
              }
            : null,
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(vf);
        },
      ),
    );
  }

  Future<void> _confirmDelete(VideoFile vf) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete video?'),
        content:
            Text('"${vf.name}" will be permanently removed from your device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.errorRed,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final file = File(vf.path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Ignore — file may already be gone or on read-only storage.
    }

    // Clean up all cached data for this video — no full rescan needed.
    await Future.wait([
      PositionService.instance.clear(vf.path),
      ThumbnailService.instance.removeThumbnail(vf.path),
      DurationCacheService.instance.removeDuration(vf.path),
    ]);

    // FIX: remove from local list and invalidate sort cache.
    setState(() {
      _deletedPaths.add(vf.path);
      _positions.remove(vf.path);
      _durations.remove(vf.path);
      _sortedCache = null; // force re-sort
    });

    // Surgically remove video from provider state + update disk cache.
    ref.read(foldersProvider.notifier).removeVideo(vf.path);

    // FIX: pop back to library if every video in the folder has been deleted.
    final remaining = widget.folder.videos
        .where((v) => !_deletedPaths.contains(v.path))
        .length;
    if (remaining == 0 && mounted) {
      Navigator.pop(context);
    }
  }

  // ── Rename ─────────────────────────────────────────────────────────────────

  Future<void> _showRenameDialog(VideoFile vf) async {
    // Extension is kept fixed — only the base name is editable, so a rename
    // can't accidentally produce a file the player no longer recognises.
    final ext = p.extension(vf.name);
    final baseName =
        ext.isNotEmpty ? vf.name.substring(0, vf.name.length - ext.length) : vf.name;
    final ctrl = TextEditingController(text: baseName);

    final newBaseName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename video'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'File name',
            suffixText: ext,
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (newBaseName == null || !mounted) return;
    final trimmed = newBaseName.trim();
    if (trimmed.isEmpty || trimmed == baseName) return;
    await _renameVideo(vf, trimmed, ext);
  }

  Future<void> _renameVideo(VideoFile vf, String newBaseName, String ext) async {
    // Strip characters that are illegal in filenames on Android/Windows.
    final sanitized = newBaseName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    if (sanitized.isEmpty) return;

    final newName = '$sanitized$ext';
    final newPath = p.join(p.dirname(vf.path), newName);
    if (newPath == vf.path) return;

    if (await File(newPath).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A file with that name already exists')),
      );
      return;
    }

    try {
      await File(vf.path).rename(newPath);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not rename file')),
      );
      return;
    }

    // Carry cached position/duration/thumbnail over to the new path so
    // nothing needs to be re-probed or re-generated after the rename.
    await Future.wait([
      PositionService.instance.rename(vf.path, newPath),
      DurationCacheService.instance.rename(vf.path, newPath),
      ThumbnailService.instance.rename(vf.path, newPath),
    ]);

    final renamed = VideoFile(
      path: newPath,
      name: newName,
      size: vf.size,
      modified: vf.modified,
      duration: vf.duration,
    );

    if (!mounted) return;
    setState(() {
      final dur = _durations.remove(vf.path);
      final pos = _positions.remove(vf.path);
      if (dur != null) _durations[newPath] = dur;
      if (pos != null) _positions[newPath] = pos;
      _renamedOverrides[vf.path] = renamed;
      _sortedCache = null; // force re-sort
    });

    ref.read(foldersProvider.notifier).renameVideo(vf.path, renamed);
  }

  // ── Sort picker ────────────────────────────────────────────────────────────

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      useSafeArea: true,
      builder: (_) => SortSheet(
        current: _sortBy,
        onSelect: (opt) {
          Navigator.pop(context);
          setState(() {
            _sortBy = opt;
            _sortedCache = null; // invalidate
          });
          PlayerPreferencesService.instance.saveSortByIndex(opt.index);
        },
      ),
    );
  }

  // ── Search toggle ──────────────────────────────────────────────────────────

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
    // FIX: use ref.watch so newPaths changes rebuild this widget automatically.
    final newPaths = ref.watch(foldersProvider.select((s) => s.newPaths));
    final sorted = _sorted(widget.folder.videos);
    final display = _filtered(sorted);
    final last =
        _positionsLoaded && _searchQuery.isEmpty ? _lastWatched(sorted) : null;

    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(_selectionMode ? Icons.close_rounded : Icons.arrow_back_rounded),
          onPressed: _selectionMode
              ? _exitSelectionMode
              : () => Navigator.pop(context),
        ),
        title: _selectionMode
            ? Text(
                '${_selectedPaths.length} selected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.folder.name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                        letterSpacing: -0.2),
                  ),
                  Text(
                    '${display.length}${_searchQuery.isNotEmpty ? ' of ${sorted.length}' : ''} '
                    'video${sorted.length == 1 ? '' : 's'}'
                    ' · ${widget.folder.totalSizeLabel}',
                    style: context.textStyles.caption,
                  ),
                ],
              ),
        actions: _selectionMode
            ? [
                IconButton(
                  icon: Icon(
                    _selectedPaths.length == display.length
                        ? Icons.select_all_rounded
                        : Icons.checklist_rounded,
                  ),
                  tooltip: _selectedPaths.length == display.length ? 'Deselect all' : 'Select all',
                  onPressed: () => _selectAll(display),
                ),
              ]
            : [
                IconButton(
                  icon: Icon(
                    _searchOpen ? Icons.search_off_rounded : Icons.search_rounded,
                    size: 20,
                    color: _searchOpen
                        ? context.colors.accent
                        : context.colors.textSecondary,
                  ),
                  tooltip: _searchOpen ? 'Close search' : 'Search',
                  onPressed: _toggleSearch,
                ),
                IconButton(
                  icon: const Icon(Icons.sort_rounded),
                  tooltip: 'Sort',
                  onPressed: _showSortSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.checklist_rounded),
                  tooltip: 'Select multiple',
                  onPressed: () => _enterSelectionMode(null),
                ),
              ],
      ),
      floatingActionButton: (_selectionMode || last == null)
          ? null
          : ResumeFab(
              position: _positions[last.path]!,
              onTap: () => _openVideo(last, sorted, forceResume: true),
            ),
      bottomNavigationBar: _selectionMode
          ? Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(
                  top: BorderSide(color: context.colors.divider),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: FilledButton.icon(
                    onPressed: _selectedPaths.isEmpty
                        ? null
                        : () => _confirmDeleteSelected(display),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.errorRed,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: context.colors.divider,
                      disabledForegroundColor: context.colors.textMuted,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(
                      'Delete Selected (${_selectedPaths.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          // Search bar (animated)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _searchOpen
                ? Padding(
                    key: const ValueKey('search'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                          color: context.colors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search videos…',
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 18, color: context.colors.textMuted),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded,
                                    size: 16, color: context.colors.textMuted),
                                onPressed: _searchCtrl.clear,
                              )
                            : null,
                      ),
                    ),
                  )
                : const SizedBox(key: ValueKey('no-search'), height: 0),
          ),

          // Video list
          Expanded(
            child: display.isEmpty
                ? _searchQuery.isNotEmpty
                    ? NoResults(query: _searchQuery)
                    : const SizedBox()
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      (_selectionMode ? 88 : (last != null ? 96 : 16)) + MediaQuery.of(context).padding.bottom,
                    ),
                    itemCount: display.length,
                    itemBuilder: (_, i) {
                      final vf = display[i];
                      final savedPos = _positions[vf.path];
                      final hasResume =
                          savedPos != null && savedPos > Duration.zero;
                      final isNew = newPaths.contains(vf.path);
                      return VideoCard(
                        vf: vf,
                        savedPos: hasResume ? savedPos : null,
                        totalDur: _durations[vf.path],
                        isNew: isNew,
                        sortBy: _sortBy,
                        selectionMode: _selectionMode,
                        isSelected: _selectedPaths.contains(vf.path),
                        onSelectToggle: () => _toggleSelection(vf.path),
                        onTap: () => _openVideo(vf, sorted),
                        onLongPress: () => _showVideoOptions(vf, sorted),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── No results ────────────────────────────────────────────────────────────────
