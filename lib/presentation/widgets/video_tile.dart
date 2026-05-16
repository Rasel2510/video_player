import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/video_entity.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            _Thumbnail(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.name, style: AppTextStyles.body,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    _ExtensionBadge(label: video.extensionLabel),
                    const SizedBox(width: 8),
                    Text(video.sizeLabel, style: AppTextStyles.mono),
                  ]),
                ],
              ),
            ),
            if (trailing != null) trailing!
            else const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textDim),
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
          color: AppColors.panel,
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.play_circle_outline,
            color: AppColors.textDim, size: 22),
      );
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
