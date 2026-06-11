import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_video_player/core/theme/app_theme.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../providers/player_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _kWhite100 = Colors.white;
const _kWhite60 = Color(0x99FFFFFF);
const _kWhite30 = Color(0x4DFFFFFF);
const _kWhite12 = Color(0x1FFFFFFF);
const _kBlack70 = Color(0xB3000000);
const _kBlack40 = Color(0x66000000);
const _kOrange = Color(0xFFFF8C00);

// ── Main overlay ──────────────────────────────────────────────────────────────

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
  final VoidCallback onToggleLock;
  final VoidCallback onToggleRepeat;

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
    required this.onToggleLock,
    required this.onToggleRepeat,
  });

  // FIX #OPT-12: Static const gradient widgets — these decorations never change
  // so creating a new Container on every build() call is wasted allocation.
  static const _kTopGradient = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xCC000000), Colors.transparent],
      ),
    ),
  );

  static const _kBottomGradient = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xCC000000), Colors.transparent],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 180,
          child: _kTopGradient,
        ),
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 200,
          child: _kBottomGradient,
        ),
        SafeArea(
          child: Column(
            children: [
              _TopBar(
                fileName: fileName,
                onBack: onBack,
                onShowSpeed: onShowSpeed,
                onShowVolume: onShowVolume,
                onShowAudio: onShowAudio,
                onShowSubtitle: onShowSubtitle,
                onToggleLock: onToggleLock,
                onToggleRepeat: onToggleRepeat,
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
                onCycleFitMode: onCycleFitMode,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────
// Two rows — like the "=" sign:
//   Row 1 : [←]  [title …]
//   Row 2 : [🔒] [speed] [🔊] [🎵] [CC] [🔁]

class _TopBar extends ConsumerWidget {
  final String fileName;
  final VoidCallback onBack;
  final VoidCallback onShowSpeed;
  final VoidCallback onShowVolume;
  final VoidCallback onShowAudio;
  final VoidCallback onShowSubtitle;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleRepeat;

  const _TopBar({
    required this.fileName,
    required this.onBack,
    required this.onShowSpeed,
    required this.onShowVolume,
    required this.onShowAudio,
    required this.onShowSubtitle,
    required this.onToggleLock,
    required this.onToggleRepeat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One combined select = one listener, one rebuild per change instead of six.
    final (
      :speed,
      :volume,
      :loopMode,
      :hasMultipleAudio,
      :hasSubtitles,
      :subtitlesEnabled,
    ) = ref.watch(playerProvider.select((s) => (
          speed: s.playbackSpeed,
          volume: s.volume,
          loopMode: s.loopMode,
          hasMultipleAudio: s.audioTracks
                  .where((t) => t.id != 'no' && t.id != 'auto')
                  .length >
              1,
          hasSubtitles: s.subtitleTracks.isNotEmpty,
          subtitlesEnabled: s.subtitlesEnabled,
        )));

    // Avoid allocating a new string on every build when speed hasn't changed.
    // The select above already prevents rebuild unless speed changes, so this
    // is just defensive clarity.
    final speedLabel =
        speed == speed.roundToDouble() ? '${speed.toInt()}×' : '$speed×';

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: back + title ──────────────────────────────────────────
          Row(
            children: [
              _GlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 20,
                onTap: onBack,
              ),
              const SizedBox(width: 8),
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
            ],
          ),

          // ── Row 2: action buttons ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Lock gesture
              _GlassIconButton(
                icon: Icons.lock_open_rounded,
                size: 19,
                onTap: onToggleLock,
              ),
              const SizedBox(width: 2),
              // Playback speed
              _MiniChip(label: speedLabel, onTap: onShowSpeed),
              const SizedBox(width: 6),
              // Volume
              _GlassIconButton(
                icon: volume == 0
                    ? Icons.volume_off_rounded
                    : volume < 50
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
                size: 20,
                onTap: onShowVolume,
                // Orange tint when volume is boosted
                boosted: volume > 100,
              ),
              // Audio track (only when multiple tracks exist)
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
              // Subtitle
              _GlassIconButton(
                icon: subtitlesEnabled && hasSubtitles
                    ? Icons.subtitles_rounded
                    : Icons.subtitles_off_outlined,
                size: 19,
                onTap: onShowSubtitle,
                active: subtitlesEnabled && hasSubtitles,
                dim: !hasSubtitles,
              ),
              const SizedBox(width: 2),
              // Repeat / loop
              _GlassIconButton(
                icon: loopMode == LoopMode.loopOne
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                size: 19,
                onTap: onToggleRepeat,
                active: loopMode.isActive,
                // Orange when loop-one, accent when loop-all
                loopMode: loopMode,
              ),
            ],
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
    // Single combined select for all three booleans.
    final (:isPlaying, :hasPrevious, :hasNext) =
        ref.watch(playerProvider.select((s) => (
              isPlaying: s.isPlaying,
              hasPrevious: s.hasPrevious,
              hasNext: s.hasNext,
            )));
    final hasSiblings = hasPrevious || hasNext;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasSiblings) ...[
          _TrackButton(
            icon: Icons.skip_previous_rounded,
            enabled: hasPrevious,
            onTap: onPlayPrevious,
          ),
          const SizedBox(width: 12),
        ],
        _SeekPill(seconds: -10, onTap: onSeekBack),
        const SizedBox(width: 16),
        _PlayButton(isPlaying: isPlaying, onTap: onTogglePlay),
        const SizedBox(width: 16),
        _SeekPill(seconds: 10, onTap: onSeekForward),
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
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _kBlack70,
          border: Border.all(color: _kWhite30, width: 1),
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 28,
          color: _kWhite100,
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
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(
          isForward ? Icons.forward_10_rounded : Icons.replay_10_rounded,
          size: 36,
          color: _kWhite60,
        ),
      ),
    );
  }
}

class _TrackButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _TrackButton(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 34, color: enabled ? _kWhite60 : _kWhite12),
        ),
      );
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final void Function(double) onSeekStart;
  final void Function(double) onSeekUpdate;
  final void Function(double) onSeekEnd;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onCycleFitMode;

  const _BottomBar({
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onToggleFullscreen,
    required this.onCycleFitMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlaybackProgressControls(
            onSeekStart: onSeekStart,
            onSeekUpdate: onSeekUpdate,
            onSeekEnd: onSeekEnd,
          ),
          const SizedBox(height: 8),
          _BottomBarActions(
            onCycleFitMode: onCycleFitMode,
            onToggleFullscreen: onToggleFullscreen,
          ),
        ],
      ),
    );
  }
}

class _PlaybackProgressControls extends ConsumerWidget {
  final void Function(double) onSeekStart;
  final void Function(double) onSeekUpdate;
  final void Function(double) onSeekEnd;

  const _PlaybackProgressControls({
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:position, :duration, :progress) =
        ref.watch(playerProvider.select((s) => (
              position: s.position,
              duration: s.duration,
              progress: s.progress,
            )));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MinimalistSlider(
          value: progress.clamp(0.0, 1.0),
          onChangeStart: onSeekStart,
          onChanged: onSeekUpdate,
          onChangeEnd: onSeekEnd,
        ),
        const SizedBox(height: 6),
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
      ],
    );
  }
}

class _BottomBarActions extends ConsumerWidget {
  final VoidCallback onCycleFitMode;
  final VoidCallback onToggleFullscreen;

  const _BottomBarActions({
    required this.onCycleFitMode,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:fitMode, :rotationMode) = ref.watch(playerProvider.select((s) => (
          fitMode: s.fitMode,
          rotationMode: s.rotationMode,
        )));

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _MiniChip(label: fitMode.label, onTap: onCycleFitMode),
        const SizedBox(width: 12),
        _GlassIconButton(
          icon: switch (rotationMode) {
            RotationMode.auto => Icons.screen_rotation_rounded,
            RotationMode.landscape => Icons.stay_current_landscape_rounded,
            RotationMode.portrait => Icons.stay_current_portrait_rounded,
          },
          size: 24,
          onTap: onToggleFullscreen,
        ),
      ],
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
  final bool boosted;
  final LoopMode? loopMode;

  const _GlassIconButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.active = false,
    this.dim = false,
    this.boosted = false,
    this.loopMode,
  });

  // Inlined as a method so the expression is evaluated once per build,
  // not allocated as a separate stack frame.
  Color _getIconColor(BuildContext context) {
    if (dim) {
      return _kWhite30;
    }
    if (boosted) {
      return _kOrange;
    }
    if (loopMode != null) {
      return switch (loopMode!) {
        LoopMode.none => _kWhite100,
        LoopMode.loopAll => context.colors.accent,
        LoopMode.loopOne => _kOrange,
      };
    }
    return active ? context.colors.accent : _kWhite100;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: size, color: _getIconColor(context)),
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
      );
}

// ── Public exports ────────────────────────────────────────────────────────────

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
