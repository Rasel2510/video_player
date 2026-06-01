import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/duration_formatter.dart';
import '../models/video_file.dart';
import '../models/video_folder.dart';
import '../presentation/widgets/thumbnail_widget.dart';
import '../services/duration_cache_service.dart';
import '../services/position_service.dart';
import '../services/recent_files_service.dart';
import 'player_screen.dart';

class FolderVideosScreen extends StatefulWidget {
  final VideoFolder folder;
  const FolderVideosScreen({super.key, required this.folder});

  @override
  State<FolderVideosScreen> createState() => _FolderVideosScreenState();
}

class _FolderVideosScreenState extends State<FolderVideosScreen> {
  final Map<String, Duration> _positions = {};
  final Map<String, Duration> _durations = {};
  bool _positionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPositions();
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

  VideoFile? get _lastWatched {
    VideoFile? best;
    for (final vf in widget.folder.videos) {
      final pos = _positions[vf.path];
      if (pos != null && pos > Duration.zero) {
        if (best == null || vf.modified.isAfter(best.modified)) best = vf;
      }
    }
    return best;
  }

  Future<void> _openVideo(VideoFile vf, {bool forceResume = false}) async {
    final savedPos = _positions[vf.path];
    Duration? resumeFrom;

    if (savedPos != null && savedPos > Duration.zero) {
      if (forceResume) {
        resumeFrom = savedPos;
      } else {
        resumeFrom = await _showResumeDialog(savedPos);
        if (resumeFrom == null) return;
      }
    }

    if (!mounted) return;
    await RecentFilesService.addRecent(vf);
    if (!mounted) return;

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        filePath: vf.path,
        fileName: vf.name,
        resumeFrom: resumeFrom,
        folderVideos: widget.folder.videos,
        initialIndex: widget.folder.videos.indexOf(vf),
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

  Future<Duration?> _showResumeDialog(Duration pos) {
    return showDialog<Duration>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Continue watching?'),
        content: Text('Paused at ${DurationFormatter.format(pos)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, Duration.zero),
            child: const Text('Start over',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, pos),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _positionsLoaded ? _lastWatched : null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.folder.name,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2)),
            Text(
              '${widget.folder.videoCount} '
              'video${widget.folder.videoCount == 1 ? '' : 's'}'
              ' · ${widget.folder.totalSizeLabel}',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
      floatingActionButton: last != null
          ? _ResumeFab(
              position: _positions[last.path]!,
              onTap: () => _openVideo(last, forceResume: true),
            )
          : null,
      body: ListView.builder(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, last != null ? 96 : 16),
        itemCount: widget.folder.videos.length,
        itemBuilder: (_, i) {
          final vf = widget.folder.videos[i];
          final savedPos = _positions[vf.path];
          final hasResume = savedPos != null && savedPos > Duration.zero;
          return _VideoCard(
            vf: vf,
            savedPos: hasResume ? savedPos : null,
            totalDur: _durations[vf.path],
            onTap: () => _openVideo(vf),
          );
        },
      ),
    );
  }
}

// ── Video card ────────────────────────────────────────────────────────────────

class _VideoCard extends StatelessWidget {
  final VideoFile vf;
  final Duration? savedPos;
  final Duration? totalDur;
  final VoidCallback onTap;

  const _VideoCard({
    required this.vf,
    required this.onTap,
    this.savedPos,
    this.totalDur,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (savedPos != null &&
            totalDur != null &&
            totalDur!.inMilliseconds > 0)
        ? (savedPos!.inMilliseconds / totalDur!.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                child: Row(
                  children: [
                    // Thumbnail with rounded corners
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                              height: 1.3,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(children: [
                            _FormatBadge(
                                vf.extension.replaceFirst('.', '')),
                            const SizedBox(width: 8),
                            Text(vf.sizeLabel,
                                style: AppTextStyles.caption),
                            if (savedPos != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                DurationFormatter.format(savedPos!),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.accent,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ]),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.textMuted),
                  ],
                ),
              ),
              // Progress bar at bottom of card
              if (savedPos != null && progress > 0)
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: AppColors.progressBg,
                  valueColor: const AlwaysStoppedAnimation(
                      AppColors.progressFill),
                ),
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
      decoration: const BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: AppRadius.xs,
      ),
      child: Text(
        ext.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
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
