import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/duration_formatter.dart';
import '../models/video_file.dart';
import '../services/position_service.dart';
import '../services/recent_files_service.dart';
import 'library_screen.dart';
import 'player_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _pickAndOpenVideo(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.single.path == null) return;
    final f = result.files.single;
    final vf = VideoFile(
      path: f.path!,
      name: f.name,
      size: f.size,
      modified: DateTime.now(),
    );
    await RecentFilesService.addRecent(vf);
    if (!context.mounted) return;
    _openVideo(context, vf);
  }

  Future<void> _openVideo(BuildContext context, VideoFile vf) async {
    final savedPos = await PositionService.instance.load(vf.path);
    Duration? resumeFrom;
    if (savedPos != null && savedPos > Duration.zero && context.mounted) {
      resumeFrom = await showDialog<Duration>(
        context: context,
        builder: (_) => _ResumeDialog(position: savedPos),
      );
      if (resumeFrom == null) return;
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          filePath: vf.path,
          fileName: vf.name,
          resumeFrom: resumeFrom,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Videos'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Open file',
            onPressed: () => _pickAndOpenVideo(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LibraryScreen(onOpenVideo: (vf) => _openVideo(context, vf)),
    );
  }
}

class _ResumeDialog extends StatelessWidget {
  final Duration position;
  const _ResumeDialog({required this.position});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Continue watching?'),
      content: Text('Paused at ${DurationFormatter.format(position)}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, Duration.zero),
          child: const Text('Start over',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, position),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
          child: const Text('Resume'),
        ),
      ],
    );
  }
}
