import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/video_entity.dart';
import 'thumbnail_widget.dart';

class VideoTile extends StatelessWidget {
  final VideoEntity video;
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
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.divider)),
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
                  Text(video.name,
                      style: context.textStyles.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Row(children: [
                    _ExtensionBadge(label: video.extensionLabel),
                    const SizedBox(width: 8),
                    Text(video.sizeLabel, style: context.textStyles.mono),
                  ]),
                ],
              ),
            ),
            if (trailing != null) trailing!
            else
              Icon(Icons.chevron_right,
                  size: 18, color: context.colors.textDim),
          ],
        ),
      ),
    );
  }
}

class _ExtensionBadge extends StatelessWidget {
  final String label;
  const _ExtensionBadge({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: context.textStyles.bodySmall.copyWith(
          color: context.colors.accent,
          letterSpacing: 1,
          fontFamily: 'monospace',
        ),
      );
}