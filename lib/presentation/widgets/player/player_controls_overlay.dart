import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../providers/player_provider.dart';

class PlayerControlsOverlay extends StatelessWidget {
  final PlayerState playerState;
  final String fileName;
  final VoidCallback onBack;
  final VoidCallback onTogglePlay;
  final VoidCallback onCycleFitMode;
  final VoidCallback onShowSpeed;
  final VoidCallback onShowVolume;
  final VoidCallback onShowAudio;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onToggleFullscreen;
  final void Function(double) onSeekStart;
  final void Function(double) onSeekUpdate;
  final void Function(double) onSeekEnd;

  const PlayerControlsOverlay({
    super.key,
    required this.playerState,
    required this.fileName,
    required this.onBack,
    required this.onTogglePlay,
    required this.onCycleFitMode,
    required this.onShowSpeed,
    required this.onShowVolume,
    required this.onShowAudio,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onToggleFullscreen,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xDD000000),
          ],
          stops: [0, 0.2, 0.7, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _TopBar(
              fileName: fileName,
              fitMode: playerState.fitMode,
              speed: playerState.playbackSpeed,
              volume: playerState.volume,
              hasMultipleAudio: playerState.audioTracks.length > 1,
              onBack: onBack,
              onCycleFitMode: onCycleFitMode,
              onShowSpeed: onShowSpeed,
              onShowVolume: onShowVolume,
              onShowAudio: onShowAudio,
            ),
            const Spacer(),
            _CenterPlayButton(
              isPlaying: playerState.isPlaying,
              onTap: onTogglePlay,
            ),
            const Spacer(),
            _BottomBar(
              position: playerState.position,
              duration: playerState.duration,
              progress: playerState.progress,
              isFullscreen: playerState.isFullscreen,
              onSeekStart: onSeekStart,
              onSeekUpdate: onSeekUpdate,
              onSeekEnd: onSeekEnd,
              onSeekBack: onSeekBack,
              onSeekForward: onSeekForward,
              onToggleFullscreen: onToggleFullscreen,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String fileName;
  final FitMode fitMode;
  final double speed;
  final double volume;
  final bool hasMultipleAudio;
  final VoidCallback onBack;
  final VoidCallback onCycleFitMode;
  final VoidCallback onShowSpeed;
  final VoidCallback onShowVolume;
  final VoidCallback onShowAudio;

  const _TopBar({
    required this.fileName,
    required this.fitMode,
    required this.speed,
    required this.volume,
    required this.hasMultipleAudio,
    required this.onBack,
    required this.onCycleFitMode,
    required this.onShowSpeed,
    required this.onShowVolume,
    required this.onShowAudio,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: onBack,
            color: Colors.white,
          ),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (hasMultipleAudio) ...[
            IconButton(
              icon: const Icon(Icons.audiotrack_outlined,
                  size: 20, color: AppColors.accent),
              onPressed: onShowAudio,
              tooltip: 'Audio Tracks',
            ),
            const SizedBox(width: 4),
          ],
          PlayerChip(label: fitMode.label, onTap: onCycleFitMode),
          const SizedBox(width: 8),
          PlayerChip(
            label: '${speed == speed.roundToDouble() ? speed.toInt() : speed}x',
            onTap: onShowSpeed,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              volume == 0
                  ? Icons.volume_off
                  : volume < 50
                      ? Icons.volume_down
                      : Icons.volume_up,
              size: 22,
            ),
            onPressed: onShowVolume,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

// ── Center Play ───────────────────────────────────────────────────────────────

class _CenterPlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _CenterPlayButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0x80000000),
          shape: BoxShape.circle,
          border: Border.all(
              color: const Color(0x4DFFFFFF), width: 1.5),
        ),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Bottom Bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final double progress;
  final bool isFullscreen;
  final void Function(double) onSeekStart;
  final void Function(double) onSeekUpdate;
  final void Function(double) onSeekEnd;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onToggleFullscreen;

  const _BottomBar({
    required this.position,
    required this.duration,
    required this.progress,
    required this.isFullscreen,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Time labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DurationFormatter.format(position),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  )),
              Text(DurationFormatter.format(duration),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  )),
            ],
          ),
          // Seek slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 3,
              thumbColor: AppColors.accent,
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.textDim,
              overlayColor: AppColors.accentDim,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChangeStart: onSeekStart,
              onChanged: onSeekUpdate,
              onChangeEnd: onSeekEnd,
            ),
          ),
          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                SeekButton(label: '−10s', onTap: onSeekBack),
                const SizedBox(width: 8),
                SeekButton(label: '+10s', onTap: onSeekForward),
              ]),
              IconButton(
                icon: Icon(
                  isFullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: onToggleFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class PlayerChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const PlayerChip({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF444444)),
            color: Colors.black38,
          ),
          child: Text(label,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontFamily: 'monospace',
              )),
        ),
      );
}

class SeekButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const SeekButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.textDim),
            color: Colors.black45,
          ),
          child: Text(label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
              )),
        ),
      );
}
