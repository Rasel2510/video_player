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
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  final isSelected = index == _selectedIndex();

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
                              _getTrackLabel(track, index, tracks.length),
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
          SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  /// Index of the row to highlight. media_kit may report the active track as
  /// the synthetic 'auto' entry (which we strip from the list) before resolving
  /// it to a concrete track, so when the reported track isn't in the list we
  /// fall back to the first track — that's what's actually playing.
  int _selectedIndex() {
    final id = selectedTrack?.id;
    final i = tracks.indexWhere((t) => t.id == id);
    return i < 0 ? 0 : i;
  }

  String _getTrackLabel(AudioTrack track, int index, int total) {
    final title = track.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final language = _languageName(track.language);
    if (language != null) return language;
    return total > 1 ? 'Track ${index + 1}' : 'Default';
  }

  static const Map<String, String> _languageNames = {
    'en': 'English', 'eng': 'English',
    'es': 'Spanish', 'spa': 'Spanish',
    'fr': 'French', 'fre': 'French', 'fra': 'French',
    'de': 'German', 'ger': 'German', 'deu': 'German',
    'it': 'Italian', 'ita': 'Italian',
    'pt': 'Portuguese', 'por': 'Portuguese',
    'ru': 'Russian', 'rus': 'Russian',
    'ja': 'Japanese', 'jpn': 'Japanese',
    'ko': 'Korean', 'kor': 'Korean',
    'zh': 'Chinese', 'chi': 'Chinese', 'zho': 'Chinese',
    'ar': 'Arabic', 'ara': 'Arabic',
    'hi': 'Hindi', 'hin': 'Hindi',
    'bn': 'Bengali', 'ben': 'Bengali',
    'ur': 'Urdu', 'urd': 'Urdu',
    'tr': 'Turkish', 'tur': 'Turkish',
    'vi': 'Vietnamese', 'vie': 'Vietnamese',
    'th': 'Thai', 'tha': 'Thai',
    'id': 'Indonesian', 'ind': 'Indonesian',
    'nl': 'Dutch', 'dut': 'Dutch', 'nld': 'Dutch',
    'pl': 'Polish', 'pol': 'Polish',
    'uk': 'Ukrainian', 'ukr': 'Ukrainian',
  };

  String? _languageName(String? code) {
    if (code == null) return null;
    final normalized = code.toLowerCase();
    if (normalized.isEmpty || normalized == 'und') return null;
    return _languageNames[normalized] ?? code.toUpperCase();
  }
}
