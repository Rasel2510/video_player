import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_video_player/core/theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';
import '../models/video_file.dart';
import '../models/video_folder.dart';
import '../presentation/providers/folders_provider.dart';
import '../presentation/widgets/resume_dialog.dart';
import '../services/duration_cache_service.dart';
import '../services/player_preferences_service.dart';
import '../services/position_service.dart';
import '../services/recent_files_service.dart';
import '../presentation/widgets/folder_videos/no_results.dart';
import '../presentation/widgets/folder_videos/resume_fab.dart';
import '../presentation/widgets/folder_videos/sort_option.dart';
import '../presentation/widgets/folder_videos/sort_sheet.dart';
import '../presentation/widgets/folder_videos/video_card.dart';
import '../presentation/widgets/folder_videos/video_options_sheet.dart';
import 'player_screen.dart';

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
    final futures = widget.folder.videos.map((vf) async {
      final pos = await PositionService.instance.load(vf.path);
      final dur = await DurationCacheService.instance.getDuration(vf.path);
      return (vf.path, pos ?? Duration.zero, dur);
    });
    final results = await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      for (final (path, pos, dur) in results) {
        _positions[path] = pos;
        if (dur != null) _durations[path] = dur;
      }
      _positionsLoaded = true;
    });
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
    final list = base.where((v) => !_deletedPaths.contains(v.path)).toList();
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

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
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

    await PositionService.instance.clear(vf.path);

    // FIX: remove from local list and invalidate sort cache.
    setState(() {
      _deletedPaths.add(vf.path);
      _positions.remove(vf.path);
      _sortedCache = null; // force re-sort
    });

    // FIX: pop back to library if every video in the folder has been deleted.
    final remaining = widget.folder.videos
        .where((v) => !_deletedPaths.contains(v.path))
        .length;
    if (remaining == 0 && mounted) {
      Navigator.pop(context);
    }

    // Trigger background library rescan so folder counts update.
    ref.read(foldersProvider.notifier).load(forceScan: true);
  }

  // ── Sort picker ────────────────────────────────────────────────────────────

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
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
        actions: [
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
        ],
      ),
      floatingActionButton: last != null
          ? ResumeFab(
              position: _positions[last.path]!,
              onTap: () => _openVideo(last, sorted, forceResume: true),
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
                    padding:
                        EdgeInsets.fromLTRB(16, 8, 16, last != null ? 96 : 16),
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
