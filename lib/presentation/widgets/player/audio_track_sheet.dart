import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/track_labels.dart';

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

  bool get _audioDisabled => selectedTrack?.id == 'no';

  /// Index of the real track to highlight. media_kit may report the active
  /// track as the synthetic 'auto' entry (which we strip from the list) before
  /// resolving it to a concrete track, so when the reported track isn't in the
  /// list we fall back to the first track — that's what's actually playing.
  int _selectedIndex() {
    final id = selectedTrack?.id;
    final i = tracks.indexWhere((t) => t.id == id);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex();
    return Container(
      clipBehavior: Clip.antiAlias,
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
              // One row per track, plus a leading "Disabled" row (index 0) that
              // mutes the audio track entirely.
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tracks.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _row(
                      context,
                      icon: Icons.volume_off_rounded,
                      label: 'Disabled',
                      isSelected: _audioDisabled,
                      onTap: () => onSelect(AudioTrack.no()),
                    );
                  }
                  final trackIndex = index - 1;
                  final track = tracks[trackIndex];
                  return _row(
                    context,
                    icon: Icons.audiotrack_outlined,
                    label: TrackLabels.trackLabel(
                      title: track.title,
                      language: track.language,
                      index: trackIndex,
                      total: tracks.length,
                    ),
                    isSelected: !_audioDisabled && trackIndex == selectedIndex,
                    onTap: () => onSelect(track),
                  );
                },
              ),
            ),
          SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        onTap();
        Navigator.pop(context);
      },
      splashColor: context.colors.accentSoft,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? context.colors.accent
                  : context.colors.textMuted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? context.colors.textPrimary
                      : context.colors.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
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
  }
}
