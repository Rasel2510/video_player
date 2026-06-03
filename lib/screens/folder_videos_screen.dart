import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/duration_formatter.dart';
import '../models/video_file.dart';
import '../models/video_folder.dart';
import '../presentation/providers/folders_provider.dart';
import '../presentation/widgets/resume_dialog.dart';
import '../presentation/widgets/thumbnail_widget.dart';
import '../services/duration_cache_service.dart';
import '../services/player_preferences_service.dart';
import '../services/position_service.dart';
import '../services/recent_files_service.dart';
import 'player_screen.dart';

// ── Sort options ──────────────────────────────────────────────────────────────

enum _SortOption { name, dateModified, size, duration }

extension _SortOptionX on _SortOption {
  String get label => switch (this) {
        _SortOption.name => 'Name',
        _SortOption.dateModified => 'Date modified',
        _SortOption.size => 'File size',
        _SortOption.duration => 'Duration',
      };
  IconData get icon => switch (this) {
        _SortOption.name => Icons.sort_by_alpha_rounded,
        _SortOption.dateModified => Icons.access_time_rounded,
        _SortOption.size => Icons.data_usage_rounded,
        _SortOption.duration => Icons.timer_rounded,
      };
}

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
  _SortOption _sortBy = _SortOption.name;

  // FIX: cache the sorted list so _sorted() is O(1) on rebuild frames
  // where nothing changed. Invalidated only when sortBy or deletedPaths changes.
  List<VideoFile>? _sortedCache;
  _SortOption? _sortedForOption;
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
      _sortBy = _SortOption.values[idx.clamp(0, _SortOption.values.length - 1)];
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
      case _SortOption.name:
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _SortOption.dateModified:
        list.sort((a, b) => b.modified.compareTo(a.modified));
      case _SortOption.size:
        list.sort((a, b) => b.size.compareTo(a.size));
      case _SortOption.duration:
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
    await RecentFilesService.addRecent(vf);
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
    final pos = await PositionService.instance.load(path);
    final dur = await DurationCacheService.instance.getDuration(path);
    if (mounted) {
      setState(() {
        _positions[path] = pos ?? Duration.zero;
        if (dur != null) _durations[path] = dur;
      });
    }
  }

  // ── Long-press options ─────────────────────────────────────────────────────

  void _showVideoOptions(VideoFile vf, List<VideoFile> playlist) {
    // FIX: haptic feedback so the long-press feels deliberate
    HapticFeedback.mediumImpact();

    final hasResume = (_positions[vf.path] ?? Duration.zero) > Duration.zero;
    showModalBottomSheet(
      context: context,
      builder: (_) => _VideoOptionsSheet(
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
      builder: (_) => _SortSheet(
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
          ? _ResumeFab(
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
                    ? _NoResults(query: _searchQuery)
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
                      return _VideoCard(
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

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 40, color: context.colors.textMuted),
          const SizedBox(height: 14),
          Text(
            'No videos match "$query"',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Video card ────────────────────────────────────────────────────────────────

class _VideoCard extends StatelessWidget {
  final VideoFile vf;
  final Duration? savedPos;
  final Duration? totalDur;
  final bool isNew;
  final _SortOption sortBy;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _VideoCard({
    required this.vf,
    required this.onTap,
    required this.onLongPress,
    this.savedPos,
    this.totalDur,
    this.isNew = false,
    this.sortBy = _SortOption.name,
  });

  String get _subtitle {
    switch (sortBy) {
      case _SortOption.dateModified:
        final d = vf.modified;
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
      case _SortOption.duration:
        return totalDur != null
            ? DurationFormatter.format(totalDur!)
            : vf.sizeLabel;
      case _SortOption.name:
      case _SortOption.size:
        return vf.sizeLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (savedPos != null &&
            totalDur != null &&
            totalDur!.inMilliseconds > 0)
        ? (savedPos!.inMilliseconds / totalDur!.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.colors.surface,
        borderRadius: AppRadius.md,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: context.colors.accentSoft,
          highlightColor: Colors.transparent,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.sm,
                      child: VideoThumbnailWidget(
                          videoPath: vf.path, width: 88, height: 58),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vf.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.colors.textPrimary,
                              height: 1.3,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isNew) ...[
                            const SizedBox(height: 3),
                            const _NewVideoBadge(),
                          ],
                          const SizedBox(height: 6),
                          Row(children: [
                            _FormatBadge(vf.extension.replaceFirst('.', '')),
                            const SizedBox(width: 8),
                            Text(_subtitle, style: context.textStyles.caption),
                            if (savedPos != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                DurationFormatter.format(savedPos!),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.colors.accent,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ]),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: context.colors.textMuted),
                  ],
                ),
              ),
              if (savedPos != null && progress > 0)
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: context.colors.progressBg,
                  valueColor:
                      AlwaysStoppedAnimation(context.colors.progressFill),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sort sheet ────────────────────────────────────────────────────────────────

class _SortSheet extends StatelessWidget {
  final _SortOption current;
  final void Function(_SortOption) onSelect;
  const _SortSheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SORT BY', style: context.textStyles.label),
          const SizedBox(height: 16),
          ..._SortOption.values.map((opt) {
            final selected = opt == current;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(opt),
                borderRadius: AppRadius.sm,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  child: Row(
                    children: [
                      Icon(opt.icon,
                          size: 20,
                          color: selected
                              ? context.colors.accent
                              : context.colors.textSecondary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected
                                ? context.colors.accent
                                : context.colors.textPrimary,
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_rounded,
                            size: 18, color: context.colors.accent),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Video options sheet ───────────────────────────────────────────────────────

class _VideoOptionsSheet extends StatelessWidget {
  final VideoFile vf;
  final bool hasResume;
  final VoidCallback onPlay;
  final VoidCallback onShare;
  final VoidCallback onCopyPath;
  final VoidCallback? onClearResume;
  final VoidCallback onDelete;

  const _VideoOptionsSheet({
    required this.vf,
    required this.hasResume,
    required this.onPlay,
    required this.onShare,
    required this.onCopyPath,
    this.onClearResume,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              vf.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary),
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: context.colors.divider),
          const SizedBox(height: 4),
          _OptionRow(
              icon: Icons.play_arrow_rounded, label: 'Play', onTap: onPlay),
          _OptionRow(icon: Icons.share_rounded, label: 'Share', onTap: onShare),
          _OptionRow(
              icon: Icons.copy_rounded, label: 'Copy path', onTap: onCopyPath),
          if (hasResume && onClearResume != null)
            _OptionRow(
                icon: Icons.replay_rounded,
                label: 'Clear resume position',
                onTap: onClearResume!),
          _OptionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: context.colors.errorRed,
              onTap: onDelete),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _OptionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.sm,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: c),
              const SizedBox(width: 14),
              Text(label,
                  style: TextStyle(
                      fontSize: 14, color: c, fontWeight: FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Format badge ──────────────────────────────────────────────────────────────

class _FormatBadge extends StatelessWidget {
  final String ext;
  const _FormatBadge(this.ext);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: context.colors.accentSoft, borderRadius: AppRadius.xs),
      child: Text(
        ext.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: context.colors.accent,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────

class _ResumeFab extends StatelessWidget {
  final Duration position;
  final VoidCallback onTap;
  const _ResumeFab({required this.position, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      icon: const Icon(Icons.play_arrow_rounded, size: 22),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resume',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2)),
          Text(
            DurationFormatter.format(position),
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w400,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

// ── NEW video badge ───────────────────────────────────────────────────────────

class _NewVideoBadge extends StatelessWidget {
  const _NewVideoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.accentSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.colors.accentGlow, width: 1),
      ),
      child: Text(
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
