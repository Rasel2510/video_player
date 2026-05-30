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
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
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
                      style: AppTextStyles.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Row(children: [
                    _ExtensionBadge(label: video.extensionLabel),
                    const SizedBox(width: 8),
                    Text(video.sizeLabel, style: AppTextStyles.mono),
                  ]),
                ],
              ),
            ),
            if (trailing != null) trailing!
            else
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textDim),
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
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.accent,
          letterSpacing: 1,
          fontFamily: 'monospace',
        ),
      );
}
