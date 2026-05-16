import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/duration_formatter.dart';
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
                    Text(video.extensionLabel,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.accent,
                          letterSpacing: 1,
                          fontFamily: 'monospace',
                        )),
                    const SizedBox(width: 8),
                    Text(video.sizeLabel, style: AppTextStyles.mono),
                    const Spacer(),
                    Text(
                      DurationFormatter.timeAgo(video.lastModified),
                      style: AppTextStyles.mono
                          .copyWith(color: AppColors.textDim, fontSize: 10),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
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
