import 'package:flutter/material.dart';
import '../models/video_file.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
        ),
        child: Row(
          children: [
            // Thumbnail placeholder
            Container(
              width: 56,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: const Icon(
                Icons.play_circle_outline,
                color: Color(0xFF444444),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.name,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFE0E0E0),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        video.extension.replaceFirst('.', '').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFE8FF00),
                          fontFamily: 'monospace',
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        video.sizeLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF555555),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
