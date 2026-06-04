import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/theme/app_theme.dart';

class AudioTrackSheet extends StatelessWidget {
  final List<AudioTrack> tracks;
  final AudioTrack? selectedTrack;
  final void Function(AudioTrack) onSelect;

  const AudioTrackSheet({
    super.key,
    required this.tracks,
    required this.selectedTrack,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ──────────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Icon(Icons.audiotrack_outlined,
                    color: context.colors.accent, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Audio Tracks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          Divider(color: context.colors.divider, height: 1),

          if (tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No audio tracks found',
                style: TextStyle(color: context.colors.textMuted, fontSize: 13),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  final isSelected = track == selectedTrack ||
                      (selectedTrack == null && index == 0);

                  return InkWell(
                    onTap: () {
                      onSelect(track);
                      Navigator.pop(context);
                    },
                    splashColor: context.colors.accentSoft,
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.audiotrack_outlined,
                            size: 18,
                            color: isSelected
                                ? context.colors.accent
                                : context.colors.textMuted,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _getTrackLabel(track, index),
                              style: TextStyle(
                                color: isSelected
                                    ? context.colors.textPrimary
                                    : context.colors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_rounded,
                                color: context.colors.accent, size: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _getTrackLabel(AudioTrack track, int index) {
    if (track.id == 'no') return 'Disabled';
    if (track.id == 'auto') return 'Auto';
    final lang = track.language?.toUpperCase();
    final title = track.title;
    if (lang != null && title != null) return '$lang — $title';
    if (lang != null) return 'Track $index ($lang)';
    if (title != null) return title;
    return 'Audio Track $index';
  }
}
