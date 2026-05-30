import 'package:flutter/material.dart';
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
  // Map<videoPath, saved position>. Null means not yet loaded, Duration.zero means none.
  final Map<String, Duration?> _positions = {};
  // Map<videoPath, total duration> — for accurate progress bar
  final Map<String, Duration?> _durations = {};

  @override
  void initState() {
    super.initState();
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    for (final vf in widget.folder.videos) {
      final pos = await PositionService.instance.load(vf.path);
      // Load cached duration (fast — SharedPrefs only, no probing here)
      final dur = await DurationCacheService.instance.getDuration(vf.path);
      if (mounted) {
        setState(() {
          _positions[vf.path] = pos ?? Duration.zero;
          _durations[vf.path] = dur;
        });
      }
    }
  }

  Future<void> _openVideo(VideoFile vf) async {
    final savedPos = _positions[vf.path];
    Duration? resumeFrom;

    // Show resume dialog only if there's a meaningful saved position
    if (savedPos != null && savedPos > Duration.zero) {
      resumeFrom = await _showResumeDialog(vf, savedPos);
      // null = user dismissed dialog → do nothing
      if (resumeFrom == null) return;
    }

    if (!mounted) return;
    await RecentFilesService.addRecent(vf);

    if (!mounted) return;
    final nav = Navigator.of(context);     // capture before async gap
    await nav.push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          filePath: vf.path,
          fileName: vf.name,
          resumeFrom: resumeFrom,
          folderVideos: widget.folder.videos,
          initialIndex: widget.folder.videos.indexOf(vf),
        ),
      ),
    );

    // Refresh positions after returning
    if (mounted) {
      final updated = await PositionService.instance.load(vf.path);
      final updatedDur = await DurationCacheService.instance.getDuration(vf.path);
      if (mounted) {
        setState(() {
          _positions[vf.path] = updated ?? Duration.zero;
          if (updatedDur != null) _durations[vf.path] = updatedDur;
        });
      }
    }
  }

  /// Returns the position to seek to, or Duration.zero to start from beginning.
  /// Returns null if dialog was dismissed.
  Future<Duration?> _showResumeDialog(VideoFile vf, Duration pos) {
    return showDialog<Duration>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Resume?',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: Text(
          'Last watched at ${DurationFormatter.format(pos)}',
          style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, Duration.zero),
            child: const Text('FROM START',
                style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, pos),
            child: const Text('RESUME',
                style: TextStyle(
                    color: Color(0xFFE8FF00),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFFAAAAAA)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.folder.name,
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
            Text(
              '${widget.folder.videoCount} video${widget.folder.videoCount == 1 ? '' : 's'}'
              ' · ${widget.folder.totalSizeLabel}',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF555555), letterSpacing: 0.5),
            ),
          ],
        ),
      ),
      body: ListView.builder(
        itemCount: widget.folder.videos.length,
        itemBuilder: (_, i) {
          final vf = widget.folder.videos[i];
          final savedPos = _positions[vf.path];
          final hasResume = savedPos != null && savedPos > Duration.zero;

          return InkWell(
            onTap: () => _openVideo(vf),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
              ),
              child: Row(
                children: [
                  // Thumbnail
                  VideoThumbnailWidget(
                      videoPath: vf.path, width: 80, height: 52),
                  const SizedBox(width: 14),

                  // Name + meta + resume bar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vf.name,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFFE0E0E0)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text(
                            vf.extension.replaceFirst('.', '').toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFE8FF00),
                                fontFamily: 'monospace',
                                letterSpacing: 1),
                          ),
                          const SizedBox(width: 8),
                          Text(vf.sizeLabel,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF555555),
                                  fontFamily: 'monospace')),
                          if (hasResume) ...[
                            const SizedBox(width: 8),
                            // Resume badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A00),
                                border: Border.all(
                                    color: const Color(0xFFE8FF00)
                                        .withValues(alpha: 0.4)),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                DurationFormatter.format(savedPos),
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFFE8FF00),
                                    fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ]),
                        // Progress bar when resume exists
                        if (hasResume) ...[
                          const SizedBox(height: 5),
                          Builder(builder: (_) {
                            final totalDur = _durations[vf.path];
                            final progress = (totalDur != null &&
                                    totalDur.inMilliseconds > 0)
                                ? (savedPos.inMilliseconds /
                                        totalDur.inMilliseconds)
                                    .clamp(0.0, 1.0)
                                : 0.0;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(1),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: const Color(0xFF2A2A2A),
                                valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFFE8FF00)),
                                minHeight: 2,
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),

                  const Icon(Icons.chevron_right,
                      size: 18, color: Color(0xFF2A2A2A)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
