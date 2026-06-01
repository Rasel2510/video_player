import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/theme/app_theme.dart';

class SubtitleSheet extends StatelessWidget {
  final List<SubtitleTrack> tracks;
  final SubtitleTrack? selectedTrack;
  final bool subtitlesEnabled;
  final void Function(SubtitleTrack) onSelect;
  final VoidCallback onToggle;

  const SubtitleSheet({
    super.key,
    required this.tracks,
    required this.selectedTrack,
    required this.subtitlesEnabled,
    required this.onSelect,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.subtitles_outlined,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 10),
                const Text('Subtitles',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                // Global on/off toggle
                GestureDetector(
                  onTap: () {
                    onToggle();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: subtitlesEnabled
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : const Color(0xFF222222),
                      border: Border.all(
                        color: subtitlesEnabled
                            ? AppColors.accent
                            : const Color(0xFF333333),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      subtitlesEnabled ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: subtitlesEnabled
                            ? AppColors.accent
                            : const Color(0xFF666666),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF1E1E1E), height: 1),

          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No subtitle tracks in this file.\nLoad an external .srt file using the button below.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF555555), fontSize: 12),
              ),
            )
          else
            // Track list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tracks.length,
              itemBuilder: (_, i) {
                final track = tracks[i];
                final isSelected =
                    subtitlesEnabled && selectedTrack?.id == track.id;
                final label = track.title?.isNotEmpty == true
                    ? track.title!
                    : track.language?.isNotEmpty == true
                        ? track.language!
                        : 'Track ${i + 1}';

                return InkWell(
                  onTap: () {
                    onSelect(track);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected
                              ? AppColors.accent
                              : const Color(0xFF444444),
                          size: 18,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF999999),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check,
                              color: AppColors.accent, size: 16),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Load external subtitle button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // TODo: file_picker to load .srt/.ass/.vtt — pass to player
              },
              icon: const Icon(Icons.folder_open_outlined,
                  size: 16, color: AppColors.accent),
              label: const Text('Load external subtitle',
                  style: TextStyle(
                      color: AppColors.accent, fontSize: 12, letterSpacing: 0.5)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF333333)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
