import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/video_file.dart';
import 'option_row.dart';

class VideoOptionsSheet extends StatelessWidget {
  final VideoFile vf;
  final bool hasResume;
  final VoidCallback onPlay;
  final VoidCallback onShare;
  final VoidCallback onCopyPath;
  final VoidCallback? onClearResume;
  final VoidCallback onDelete;

  const VideoOptionsSheet({
    super.key,
    required this.vf,
    required this.hasResume,
    required this.onPlay,
    required this.onShare,
    required this.onCopyPath,
    this.onClearResume,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              vf.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary),
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: context.colors.divider),
          const SizedBox(height: 4),
          OptionRow(
              icon: Icons.play_arrow_rounded, label: 'Play', onTap: onPlay),
          OptionRow(icon: Icons.share_rounded, label: 'Share', onTap: onShare),
          OptionRow(
              icon: Icons.copy_rounded, label: 'Copy path', onTap: onCopyPath),
          if (hasResume && onClearResume != null)
            OptionRow(
                icon: Icons.replay_rounded,
                label: 'Clear resume position',
                onTap: onClearResume!),
          OptionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: context.colors.errorRed,
              onTap: onDelete),
        ],
      ),
    );
  }
}
