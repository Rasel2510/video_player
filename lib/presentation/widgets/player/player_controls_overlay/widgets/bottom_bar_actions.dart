part of '../player_controls_overlay.dart';

/// Feature-rich bottom action toolbar (MX/VLC-style): every control is visible
/// and one tap away. Horizontally scrollable so it never overflows on narrow
/// screens. A single combined `select` keeps this to one rebuild per change.
class _BottomBarActions extends ConsumerWidget {
  final VoidCallback onShowSpeed;
  final VoidCallback onShowVolume;
  final VoidCallback onShowAudio;
  final VoidCallback onShowSubtitle;
  final VoidCallback onCycleFitMode;
  final VoidCallback onPip;
  final VoidCallback onSleepTimer;
  final VoidCallback onAudioMode;
  final VoidCallback onToggleRepeat;
  final VoidCallback onCycleAbRepeat;

  const _BottomBarActions({
    required this.onShowSpeed,
    required this.onShowVolume,
    required this.onShowAudio,
    required this.onShowSubtitle,
    required this.onCycleFitMode,
    required this.onPip,
    required this.onSleepTimer,
    required this.onAudioMode,
    required this.onToggleRepeat,
    required this.onCycleAbRepeat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (
      :speed,
      :volume,
      :fitMode,
      :loopMode,
      :hasMultipleAudio,
      :hasSubtitles,
      :subtitlesEnabled,
      :sleepActive,
      :abState,
    ) = ref.watch(playerProvider.select((s) => (
          speed: s.playbackSpeed,
          volume: s.volume,
          fitMode: s.fitMode,
          loopMode: s.loopMode,
          hasMultipleAudio: s.audioTracks.length > 1,
          hasSubtitles: s.subtitleTracks.isNotEmpty,
          subtitlesEnabled: s.subtitlesEnabled,
          sleepActive: s.sleepTimerEndsAt != null || s.sleepTimerEndOfVideo,
          // 0 = off, 1 = A set (waiting for B), 2 = looping A↔B.
          abState: s.abRepeatStart == null
              ? 0
              : (s.abRepeatEnd == null ? 1 : 2),
        )));

    final speedLabel =
        speed == speed.roundToDouble() ? '${speed.toInt()}×' : '$speed×';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Center the toolbar when it fits; scroll when it doesn't.
      physics: const ClampingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Speed ──────────────────────────────────────────────────────
          _MiniChip(label: speedLabel, onTap: onShowSpeed),
          const SizedBox(width: 8),

          // ── Volume ─────────────────────────────────────────────────────
          _GlassIconButton(
            icon: volume == 0
                ? Icons.volume_off_rounded
                : volume < 50
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            size: 21,
            onTap: onShowVolume,
            boosted: volume > 100,
          ),
          const SizedBox(width: 2),

          // ── Audio track ────────────────────────────────────────────────
          _GlassIconButton(
            icon: Icons.audiotrack_rounded,
            size: 20,
            onTap: onShowAudio,
            active: hasMultipleAudio,
          ),
          const SizedBox(width: 2),

          // ── Subtitle ───────────────────────────────────────────────────
          _GlassIconButton(
            icon: subtitlesEnabled && hasSubtitles
                ? Icons.subtitles_rounded
                : Icons.subtitles_off_outlined,
            size: 20,
            onTap: onShowSubtitle,
            active: subtitlesEnabled && hasSubtitles,
            dim: !hasSubtitles,
          ),

          const _ToolbarDivider(),

          // ── A-B repeat ─────────────────────────────────────────────────
          _MiniChip(
            label: abState == 1 ? 'A•' : 'A-B',
            onTap: onCycleAbRepeat,
            color: abState == 0 ? null : context.colors.accent,
          ),
          const SizedBox(width: 8),

          // ── Loop / repeat ──────────────────────────────────────────────
          _GlassIconButton(
            icon: loopMode == LoopMode.loopOne
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            size: 20,
            onTap: onToggleRepeat,
            active: loopMode.isActive,
            loopMode: loopMode,
          ),

          const _ToolbarDivider(),

          // ── Fit mode ───────────────────────────────────────────────────
          _MiniChip(label: fitMode.label, onTap: onCycleFitMode),
          const SizedBox(width: 8),

          // ── Picture-in-Picture ─────────────────────────────────────────
          _GlassIconButton(
            icon: Icons.picture_in_picture_alt_rounded,
            size: 19,
            onTap: onPip,
          ),
          const SizedBox(width: 2),

          // ── Sleep timer ────────────────────────────────────────────────
          _GlassIconButton(
            icon: Icons.bedtime_rounded,
            size: 19,
            onTap: onSleepTimer,
            active: sleepActive,
          ),
          const SizedBox(width: 2),

          // ── Background audio mode ──────────────────────────────────────
          _GlassIconButton(
            icon: Icons.headphones_rounded,
            size: 19,
            onTap: onAudioMode,
          ),
        ],
      ),
    );
  }
}

/// Thin vertical separator between logical groups in the action toolbar.
class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: _kWhite12,
      );
}

// ── Custom minimalist slider ──────────────────────────────────────────────────
