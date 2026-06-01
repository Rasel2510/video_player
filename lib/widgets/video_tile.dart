import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.md,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: AppColors.accentSoft,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: AppRadius.sm,
                  child: VideoThumbnailWidget(
                      videoPath: video.path, width: 88, height: 58),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.name,
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
                            video.extension.replaceFirst('.', '')),
                        const SizedBox(width: 8),
                        Text(video.sizeLabel, style: AppTextStyles.caption),
                      ]),
                    ],
                  ),
                ),
                trailing ??
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatBadge extends StatelessWidget {
  final String ext;
  const _FormatBadge(this.ext);

  @override
  Widget build(BuildContext context) => Container(
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
