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
                color: context.colors.accent,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (tracks.isEmpty)
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No audio tracks found',
                style: TextStyle(color: context.colors.textDim, fontSize: 13),
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
                      color: isSelected ? context.colors.accent : context.colors.textDim,
                    ),
                    title: Text(
                      _getTrackLabel(track, index),
                      style: TextStyle(
                        color: isSelected ? Colors.white : context.colors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: context.colors.accent, size: 18)
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