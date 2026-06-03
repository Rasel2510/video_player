import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../domain/entities/video_entity.dart';

class RecentTile extends StatelessWidget {
  final VideoEntity video;
  final VoidCallback onTap;

  const RecentTile({super.key, required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.divider)),
        ),
        child: Row(
          children: [
            _Thumbnail(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.name, style: context.textStyles.body,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(video.extensionLabel,
                        style: context.textStyles.bodySmall.copyWith(
                          color: context.colors.accent,
                          letterSpacing: 1,
                          fontFamily: 'monospace',
                        )),
                    const SizedBox(width: 8),
                    Text(video.sizeLabel, style: context.textStyles.mono),
                    const Spacer(),
                    Text(
                      DurationFormatter.timeAgo(video.lastModified),
                      style: context.textStyles.mono
                          .copyWith(color: context.colors.textDim, fontSize: 10),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                size: 18, color: context.colors.textDim),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 40,
        decoration: BoxDecoration(
          color: context.colors.panel,
          border: Border.all(color: context.colors.border),
        ),
        child: Icon(Icons.play_circle_outline,
            color: context.colors.textDim, size: 22),
      );
}