part of '../player_controls_overlay.dart';

class _BottomBar extends StatelessWidget {
  final void Function(double) onSeekStart;
  final void Function(double) onSeekUpdate;
  final void Function(double) onSeekEnd;
  final VoidCallback onCycleFitMode;
  final VoidCallback onShowSpeed;
  final VoidCallback onShowVolume;
  final VoidCallback onShowAudio;
  final VoidCallback onShowSubtitle;
  final VoidCallback onPip;
  final VoidCallback onSleepTimer;
  final VoidCallback onAudioMode;
  final VoidCallback onToggleRepeat;
  final VoidCallback onCycleAbRepeat;

  const _BottomBar({
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onCycleFitMode,
    required this.onShowSpeed,
    required this.onShowVolume,
    required this.onShowAudio,
    required this.onShowSubtitle,
    required this.onPip,
    required this.onSleepTimer,
    required this.onAudioMode,
    required this.onToggleRepeat,
    required this.onCycleAbRepeat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlaybackProgressControls(
            onSeekStart: onSeekStart,
            onSeekUpdate: onSeekUpdate,
            onSeekEnd: onSeekEnd,
          ),
          const SizedBox(height: 10),
          _BottomBarActions(
            onShowSpeed: onShowSpeed,
            onShowVolume: onShowVolume,
            onShowAudio: onShowAudio,
            onShowSubtitle: onShowSubtitle,
            onCycleFitMode: onCycleFitMode,
            onPip: onPip,
            onSleepTimer: onSleepTimer,
            onAudioMode: onAudioMode,
            onToggleRepeat: onToggleRepeat,
            onCycleAbRepeat: onCycleAbRepeat,
          ),
        ],
      ),
    );
  }
}
