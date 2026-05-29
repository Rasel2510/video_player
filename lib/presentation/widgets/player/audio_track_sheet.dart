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
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'AUDIO TRACKS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: AppColors.accent,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No audio tracks found',
                style: TextStyle(color: AppColors.textDim, fontSize: 13),
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
                      (selectedTrack == null && index == 0); // fallback for default
                  
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.audiotrack_outlined,
                      size: 18,
                      color: isSelected ? AppColors.accent : AppColors.textDim,
                    ),
                    title: Text(
                      _getTrackLabel(track, index),
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.accent, size: 18)
                        : null,
                    onTap: () {
                      onSelect(track);
                      Navigator.pop(context);
                    },
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
    if (lang != null && title != null) return '$lang - $title';
    if (lang != null) return 'AUDIO $index ($lang)';
    if (title != null) return title;
    return 'AUDIO TRACK $index';
  }
}
