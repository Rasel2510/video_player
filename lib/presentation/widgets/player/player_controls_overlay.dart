import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../providers/player_provider.dart';

class PlayerControlsOverlay extends StatelessWidget {
  final String fileName;
  final VoidCallback onBack;
  final VoidCallback onTogglePlay;
  final VoidCallback onCycleFitMode;
  final VoidCallback onShowSpeed;
  final VoidCallback onShowVolume;
  final VoidCallback onShowAudio;
  final VoidCallback onShowSubtitle;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onToggleFullscreen;
  final void Function(double) onSeekStart;
  final void Function(double) onSeekUpdate;
  final void Function(double) onSeekEnd;
  final VoidCallback onPlayNext;
  final VoidCallback onPlayPrevious;

  const PlayerControlsOverlay({
    super.key,
    required this.fileName,
    required this.onBack,
    required this.onTogglePlay,
    required this.onCycleFitMode,
    required this.onShowSpeed,
    required this.onShowVolume,
    required this.onShowAudio,
    required this.onShowSubtitle,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onToggleFullscreen,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onPlayNext,
    required this.onPlayPrevious,
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
              onBack: onBack,
              onCycleFitMode: onCycleFitMode,
              onShowSpeed: onShowSpeed,
              onShowVolume: onShowVolume,
              onShowAudio: onShowAudio,
              onShowSubtitle: onShowSubtitle,
            ),
            const Spacer(),
            _CenterControls(
              onTogglePlay: onTogglePlay,
              onPlayPrevious: onPlayPrevious,
              onPlayNext: onPlayNext,
            ),
            const Spacer(),
            _BottomBar(
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

class _TopBar extends ConsumerWidget {
  final String fileName;
  final VoidCallback onBack;
  final VoidCallback onCycleFitMode;
  final VoidCallback onShowSpeed;
  final VoidCallback onShowVolume;
  final VoidCallback onShowAudio;
  final VoidCallback onShowSubtitle;

  const _TopBar({
    required this.fileName,
    required this.onBack,
    required this.onCycleFitMode,
    required this.onShowSpeed,
    required this.onShowVolume,
    required this.onShowAudio,
    required this.onShowSubtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitMode = ref.watch(playerProvider.select((s) => s.fitMode));
    final speed = ref.watch(playerProvider.select((s) => s.playbackSpeed));
    final volume = ref.watch(playerProvider.select((s) => s.volume));
    final hasMultipleAudio = ref.watch(playerProvider.select(
        (s) => s.audioTracks.where((t) => t.id != 'no' && t.id != 'auto').length > 1));
    final hasSubtitles = ref.watch(
        playerProvider.select((s) => s.subtitleTracks.isNotEmpty));
    final subtitlesEnabled = ref.watch(
        playerProvider.select((s) => s.subtitlesEnabled));

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
          // Subtitle button — always shown; dimmed when no tracks or disabled
          IconButton(
            icon: Icon(
              subtitlesEnabled && hasSubtitles
                  ? Icons.subtitles
                  : Icons.subtitles_outlined,
              size: 20,
              color: subtitlesEnabled && hasSubtitles
                  ? AppColors.accent
                  : Colors.white38,
            ),
            onPressed: onShowSubtitle,
            tooltip: 'Subtitles',
          ),
          const SizedBox(width: 4),
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

// ── Center Controls (Play + Prev/Next) ────────────────────────────────────────

class _CenterControls extends ConsumerWidget {
  final VoidCallback onTogglePlay;
  final VoidCallback onPlayPrevious;
  final VoidCallback onPlayNext;

  const _CenterControls({
    required this.onTogglePlay,
    required this.onPlayPrevious,
    required this.onPlayNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final hasPrevious = ref.watch(playerProvider.select((s) => s.hasPrevious));
    final hasNext = ref.watch(playerProvider.select((s) => s.hasNext));
    final hasSiblings = hasPrevious || hasNext;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous button (only if folder context exists)
        if (hasSiblings) ...[
          _NavButton(
            icon: Icons.skip_previous_rounded,
            enabled: hasPrevious,
            onTap: onPlayPrevious,
          ),
          const SizedBox(width: 20),
        ],

        // Play/Pause
        GestureDetector(
          onTap: onTogglePlay,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0x80000000),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x4DFFFFFF), width: 1.5),
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              size: 40,
              color: Colors.white,
            ),
          ),
        ),

        // Next button (only if folder context exists)
        if (hasSiblings) ...[
          const SizedBox(width: 20),
          _NavButton(
            icon: Icons.skip_next_rounded,
            enabled: hasNext,
            onTap: onPlayNext,
          ),
        ],
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black38,
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled
                  ? const Color(0x33FFFFFF)
                  : const Color(0x11FFFFFF),
            ),
          ),
          child: Icon(
            icon,
            size: 28,
            color: enabled ? Colors.white : Colors.white24,
          ),
        ),
      );
}

// ── Bottom Bar ────────────────────────────────────────────────────────────────

class _BottomBar extends ConsumerWidget {
  final void Function(double) onSeekStart;
  final void Function(double) onSeekUpdate;
  final void Function(double) onSeekEnd;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onToggleFullscreen;

  const _BottomBar({
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playerProvider.select((s) => s.position));
    final duration = ref.watch(playerProvider.select((s) => s.duration));
    final progress = ref.watch(playerProvider.select((s) => s.progress));
    final isFullscreen = ref.watch(playerProvider.select((s) => s.isFullscreen));

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
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
                  isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
