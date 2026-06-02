import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../providers/player_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _kWhite100 = Colors.white;
const _kWhite60  = Color(0x99FFFFFF);
const _kWhite30  = Color(0x4DFFFFFF);
const _kWhite12  = Color(0x1FFFFFFF);
const _kBlack70  = Color(0xB3000000);
const _kBlack40  = Color(0x66000000);
const _kAccent   = Color(0xFFE8FF58); // fresh lime accent

// ── Main overlay ─────────────────────────────────────────────────────────────

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
    return Stack(
      children: [
        // Top gradient
        Positioned(
          top: 0, left: 0, right: 0,
          height: 160,
          child: _buildGradient(Alignment.topCenter, Alignment.bottomCenter),
        ),
        // Bottom gradient
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: 200,
          child: _buildGradient(Alignment.bottomCenter, Alignment.topCenter),
        ),
        // Content
        SafeArea(
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
                onSeekBack: onSeekBack,
                onSeekForward: onSeekForward,
              ),
              const Spacer(),
              _BottomBar(
                onSeekStart: onSeekStart,
                onSeekUpdate: onSeekUpdate,
                onSeekEnd: onSeekEnd,
                onToggleFullscreen: onToggleFullscreen,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradient(Alignment begin, Alignment end) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: const [Color(0xCC000000), Colors.transparent],
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

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
    final speed   = ref.watch(playerProvider.select((s) => s.playbackSpeed));
    final volume  = ref.watch(playerProvider.select((s) => s.volume));
    final hasMultipleAudio = ref.watch(playerProvider.select(
        (s) => s.audioTracks.where((t) => t.id != 'no' && t.id != 'auto').length > 1));
    final hasSubtitles      = ref.watch(playerProvider.select((s) => s.subtitleTracks.isNotEmpty));
    final subtitlesEnabled  = ref.watch(playerProvider.select((s) => s.subtitlesEnabled));

    final speedLabel = speed == speed.roundToDouble()
        ? '${speed.toInt()}×'
        : '${speed}×';

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          // Back button
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 20,
            onTap: onBack,
          ),
          const SizedBox(width: 8),
          // Title
          Expanded(
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _kWhite100,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Right-side action chips
          _MiniChip(label: fitMode.label, onTap: onCycleFitMode),
          const SizedBox(width: 6),
          _MiniChip(label: speedLabel, onTap: onShowSpeed),
          const SizedBox(width: 6),
          _GlassIconButton(
            icon: volume == 0
                ? Icons.volume_off_rounded
                : volume < 50
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            size: 20,
            onTap: onShowVolume,
          ),
          if (hasMultipleAudio) ...[
            const SizedBox(width: 2),
            _GlassIconButton(
              icon: Icons.audiotrack_rounded,
              size: 19,
              onTap: onShowAudio,
              active: true,
            ),
          ],
          const SizedBox(width: 2),
          _GlassIconButton(
            icon: subtitlesEnabled && hasSubtitles
                ? Icons.subtitles_rounded
                : Icons.subtitles_off_outlined,
            size: 19,
            onTap: onShowSubtitle,
            active: subtitlesEnabled && hasSubtitles,
            dim: !hasSubtitles,
          ),
        ],
      ),
    );
  }
}

// ── Center controls ───────────────────────────────────────────────────────────

class _CenterControls extends ConsumerWidget {
  final VoidCallback onTogglePlay;
  final VoidCallback onPlayPrevious;
  final VoidCallback onPlayNext;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;

  const _CenterControls({
    required this.onTogglePlay,
    required this.onPlayPrevious,
    required this.onPlayNext,
    required this.onSeekBack,
    required this.onSeekForward,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying   = ref.watch(playerProvider.select((s) => s.isPlaying));
    final hasPrevious = ref.watch(playerProvider.select((s) => s.hasPrevious));
    final hasNext     = ref.watch(playerProvider.select((s) => s.hasNext));
    final hasSiblings = hasPrevious || hasNext;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Previous track
        if (hasSiblings) ...[
          _TrackButton(
            icon: Icons.skip_previous_rounded,
            enabled: hasPrevious,
            onTap: onPlayPrevious,
          ),
          const SizedBox(width: 12),
        ],

        // Seek back −10
        _SeekPill(seconds: -10, onTap: onSeekBack),
        const SizedBox(width: 16),

        // Play / Pause — main button
        _PlayButton(isPlaying: isPlaying, onTap: onTogglePlay),

        const SizedBox(width: 16),

        // Seek forward +10
        _SeekPill(seconds: 10, onTap: onSeekForward),

        // Next track
        if (hasSiblings) ...[
          const SizedBox(width: 12),
          _TrackButton(
            icon: Icons.skip_next_rounded,
            enabled: hasNext,
            onTap: onPlayNext,
          ),
        ],
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kBlack70,
              border: Border.all(color: _kWhite30, width: 1),
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 38,
              color: _kWhite100,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeekPill extends StatelessWidget {
  final int seconds;
  final VoidCallback onTap;

  const _SeekPill({required this.seconds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isForward = seconds > 0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isForward ? Icons.forward_10_rounded : Icons.replay_10_rounded,
            size: 36,
            color: _kWhite60,
          ),
        ],
      ),
    );
  }
}

class _TrackButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _TrackButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Icon(
          icon,
          size: 34,
          color: enabled ? _kWhite60 : _kWhite12,
        ),
      );
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends ConsumerWidget {
  final void Function(double) onSeekStart;
  final void Function(double) onSeekUpdate;
  final void Function(double) onSeekEnd;
  final VoidCallback onToggleFullscreen;

  const _BottomBar({
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position    = ref.watch(playerProvider.select((s) => s.position));
    final duration    = ref.watch(playerProvider.select((s) => s.duration));
    final progress    = ref.watch(playerProvider.select((s) => s.progress));
    final isFullscreen = ref.watch(playerProvider.select((s) => s.isFullscreen));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Progress bar ──────────────────────────────────────────────────
          _MinimalistSlider(
            value: progress.clamp(0.0, 1.0),
            onChangeStart: onSeekStart,
            onChanged: onSeekUpdate,
            onChangeEnd: onSeekEnd,
          ),
          const SizedBox(height: 6),
          // ── Time row ─────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DurationFormatter.format(position),
                style: const TextStyle(
                  color: _kWhite100,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              // Remaining time
              Text(
                '−${DurationFormatter.format(duration - position)}',
                style: const TextStyle(
                  color: _kWhite60,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Bottom actions row ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _GlassIconButton(
                icon: isFullscreen
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                size: 24,
                onTap: onToggleFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Custom minimalist slider ──────────────────────────────────────────────────

class _MinimalistSlider extends StatelessWidget {
  final double value;
  final void Function(double) onChangeStart;
  final void Function(double) onChanged;
  final void Function(double) onChangeEnd;

  const _MinimalistSlider({
    required this.value,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        thumbColor: _kWhite100,
        activeTrackColor: _kWhite100,
        inactiveTrackColor: _kWhite30,
        overlayColor: _kWhite12,
      ),
      child: Slider(
        value: value,
        onChangeStart: onChangeStart,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final bool active;
  final bool dim;

  const _GlassIconButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.active = false,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: size,
          color: dim
              ? _kWhite30
              : active
                  ? _kAccent
                  : _kWhite100,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MiniChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: _kBlack40,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kWhite12),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: _kWhite100,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      );
}

// ── Public chip (used externally) ─────────────────────────────────────────────

class PlayerChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const PlayerChip({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => _MiniChip(label: label, onTap: onTap);
}

class SeekButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const SeekButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _kBlack40,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kWhite12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: _kWhite60,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
}
