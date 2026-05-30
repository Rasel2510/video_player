import 'package:flutter/material.dart';
import '../models/video_file.dart';
import '../presentation/widgets/thumbnail_widget.dart';

class VideoTile extends StatelessWidget {
  final VideoFile video;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const VideoTile({
    super.key,
    required this.video,
    required this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
        ),
        child: Row(
          children: [
            VideoThumbnailWidget(
              videoPath: video.path,
              width: 80,
              height: 52,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    video.name,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFFE0E0E0)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(children: [
                    _Badge(video.extension
                        .replaceFirst('.', '')
                        .toUpperCase()),
                    const SizedBox(width: 8),
                    Text(video.sizeLabel,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF555555),
                            fontFamily: 'monospace')),
                  ]),
                ],
              ),
            ),
            if (trailing != null) trailing!
            else
              const Icon(Icons.chevron_right,
                  size: 18, color: Color(0xFF2A2A2A)),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
            fontSize: 10,
            color: Color(0xFFE8FF00),
            fontFamily: 'monospace',
            letterSpacing: 1),
      );
}
