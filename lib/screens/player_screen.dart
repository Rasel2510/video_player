import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/video_file.dart';
import '../presentation/providers/player_provider.dart';
import '../presentation/widgets/player/player_controls_overlay.dart';
import '../presentation/widgets/player/speed_sheet.dart';
import '../presentation/widgets/player/volume_sheet.dart';
import '../presentation/widgets/player/audio_track_sheet.dart';
import '../presentation/widgets/player/subtitle_sheet.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String filePath;
  final String fileName;
  final Duration? resumeFrom;
  final List<VideoFile> folderVideos;
  final int initialIndex;

  const PlayerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.resumeFrom,
    this.folderVideos = const [],
    this.initialIndex = -1,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  double _dragStartDx = 0;
  bool _swipeActive = false;

  // FIX #9: Seek flash animation controller
  late final AnimationController _seekFlashCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _seekFlashAnim = CurvedAnimation(
    parent: _seekFlashCtrl,
    curve: Curves.easeOut,
  );

  // FIX #9: track which side the double-tap was on
  bool _seekFlashLeft = false;
  bool _seekFlashRight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playerProvider.notifier).init(
        widget.filePath,
        resumeFrom: widget.resumeFrom,
        folderVideos: widget.folderVideos,
        initialIndex: widget.initialIndex,
      );
    });
  }

  @override
  void dispose() {
    _seekFlashCtrl.dispose();
    // FIX #13: Call dispose() but don't await it here (ConsumerState.dispose
    // must be synchronous). The notifier handles its own cleanup gracefully.
    // The critical audio-stop path (pause + channel null) is synchronous-first
    // inside the notifier, so this is safe.
    ref.read(playerProvider.notifier).dispose();
    super.dispose();
  }

  void _triggerSeekFlash(bool isLeft) {
    setState(() {
      _seekFlashLeft  = isLeft;
      _seekFlashRight = !isLeft;
    });
    _seekFlashCtrl.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _seekFlashLeft  = false;
          _seekFlashRight = false;
        });
      }
    });
  }

  void _showSpeedSheet(BuildContext context, double currentSpeed) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SpeedSheet(
        currentSpeed: currentSpeed,
        onSelect: (s) => ref.read(playerProvider.notifier).setSpeed(s),
      ),
    );
  }

  void _showVolumeSheet(BuildContext context, double currentVolume) {
    showModalBottomSheet(
      context: context,
      builder: (_) => VolumeSheet(
        volume: currentVolume,
        onChanged: (v) => ref.read(playerProvider.notifier).setVolume(v),
      ),
    );
  }

  void _showAudioTrackSheet(BuildContext context) {
    final state = ref.read(playerProvider);
    showModalBottomSheet(
      context: context,
      builder: (_) => AudioTrackSheet(
        tracks: state.audioTracks,
        selectedTrack: state.selectedAudioTrack,
        onSelect: (t) => ref.read(playerProvider.notifier).setAudioTrack(t),
      ),
    );
  }

  void _showSubtitleSheet(BuildContext context) {
    final state = ref.read(playerProvider);
    showModalBottomSheet(
      context: context,
      builder: (_) => SubtitleSheet(
        tracks: state.subtitleTracks,
        selectedTrack: state.selectedSubtitleTrack,
        subtitlesEnabled: state.subtitlesEnabled,
        onSelect: (t) => ref.read(playerProvider.notifier).setSubtitleTrack(t),
        onToggle: () => ref.read(playerProvider.notifier).toggleSubtitles(),
      ),
    );
  }

  BoxFit _boxFit(FitMode mode) => switch (mode) {
        FitMode.contain => BoxFit.contain,
        FitMode.cover   => BoxFit.cover,
        FitMode.fill    => BoxFit.fill,
        FitMode.natural => BoxFit.scaleDown,
      };

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(playerProvider.notifier);
    final size     = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer(
        builder: (context, ref, child) {
          final controlsVisible =
              ref.watch(playerProvider.select((s) => s.controlsVisible));
          return GestureDetector(
            onTap: () {
              if (!_swipeActive) {
                controlsVisible
                    ? notifier.hideControls()
                    : notifier.showControls();
              }
            },
            onDoubleTapDown: (details) {
              final isLeft = details.globalPosition.dx < size.width / 2;
              if (isLeft) {
                notifier.seekRelative(-10);
              } else {
                notifier.seekRelative(10);
              }
              // FIX #9: trigger the side flash
              _triggerSeekFlash(isLeft);
            },
            onVerticalDragStart: (details) {
              _dragStartDx = details.globalPosition.dx;
              _swipeActive = true;
              notifier.startSwipe(_dragStartDx, size.width);
            },
            onVerticalDragUpdate: (details) {
              notifier.updateSwipe(details.delta.dy, size.height);
            },
            onVerticalDragEnd: (_) {
              _swipeActive = false;
              notifier.endSwipe();
            },
            onVerticalDragCancel: () {
              _swipeActive = false;
              notifier.endSwipe();
            },
            child: child,
          );
        },
        child: Stack(
          children: [
            // ── Video ────────────────────────────────────────────────────
            Consumer(
              builder: (context, ref, _) {
                final isInitialized =
                    ref.watch(playerProvider.select((s) => s.isInitialized));
                final fitMode =
                    ref.watch(playerProvider.select((s) => s.fitMode));
                if (isInitialized && notifier.videoController != null) {
                  return Positioned.fill(
                    child: Video(
                      controller: notifier.videoController!,
                      fit: _boxFit(fitMode),
                      controls: NoVideoControls,
                    ),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),

            // ── FIX #9: Double-tap seek flash overlays ───────────────────
            if (_seekFlashLeft)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: size.width / 2,
                child: _SeekFlash(
                  animation: _seekFlashAnim,
                  isForward: false,
                ),
              ),
            if (_seekFlashRight)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: size.width / 2,
                child: _SeekFlash(
                  animation: _seekFlashAnim,
                  isForward: true,
                ),
              ),

            // ── Swipe HUD ────────────────────────────────────────────────
            Consumer(
              builder: (context, ref, _) {
                final gesture =
                    ref.watch(playerProvider.select((s) => s.swipeGesture));
                final value =
                    ref.watch(playerProvider.select((s) => s.swipeValue));
                if (gesture == SwipeGesture.none) return const SizedBox();
                return _SwipeHud(gesture: gesture, value: value);
              },
            ),

            // ── Controls overlay ─────────────────────────────────────────
            Consumer(
              builder: (context, ref, _) {
                final isInitialized =
                    ref.watch(playerProvider.select((s) => s.isInitialized));
                if (!isInitialized) return const SizedBox();
                final controlsVisible =
                    ref.watch(playerProvider.select((s) => s.controlsVisible));
                final currentVideo =
                    ref.watch(playerProvider.select((s) => s.currentVideo));
                final displayName = currentVideo?.name ?? widget.fileName;
                return AnimatedOpacity(
                  opacity: controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !controlsVisible,
                    child: PlayerControlsOverlay(
                      fileName: displayName,
                      onBack: () => Navigator.pop(context),
                      onTogglePlay: notifier.togglePlay,
                      onCycleFitMode: notifier.cycleFitMode,
                      onShowSpeed: () => _showSpeedSheet(
                          context, ref.read(playerProvider).playbackSpeed),
                      onShowVolume: () => _showVolumeSheet(
                          context, ref.read(playerProvider).volume),
                      onShowAudio: () => _showAudioTrackSheet(context),
                      onShowSubtitle: () => _showSubtitleSheet(context),
                      onSeekBack: () => notifier.seekRelative(-10),
                      onSeekForward: () => notifier.seekRelative(10),
                      onToggleFullscreen: notifier.toggleFullscreen,
                      onSeekStart: notifier.beginSeek,
                      onSeekUpdate: notifier.updateSeek,
                      onSeekEnd: notifier.endSeek,
                      onPlayNext: notifier.playNext,
                      onPlayPrevious: notifier.playPrevious,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── FIX #9: Seek flash widget ─────────────────────────────────────────────────

class _SeekFlash extends StatelessWidget {
  final Animation<double> animation;
  final bool isForward;

  const _SeekFlash({required this.animation, required this.isForward});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final opacity = (1.0 - animation.value).clamp(0.0, 1.0);
        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity * 0.15),
              borderRadius: BorderRadius.horizontal(
                left: isForward ? Radius.zero : const Radius.circular(999),
                right: isForward ? const Radius.circular(999) : Radius.zero,
              ),
            ),
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isForward
                          ? Icons.forward_10_rounded
                          : Icons.replay_10_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isForward ? '+10s' : '-10s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Swipe HUD ─────────────────────────────────────────────────────────────────

class _SwipeHud extends StatelessWidget {
  final SwipeGesture gesture;
  final double value;

  const _SwipeHud({required this.gesture, required this.value});

  @override
  Widget build(BuildContext context) {
    final isBrightness = gesture == SwipeGesture.brightness;

    // Choose icon based on level
    final IconData icon;
    if (isBrightness) {
      icon = value > 0.6
          ? Icons.brightness_high_rounded
          : value > 0.3
              ? Icons.brightness_medium_rounded
              : Icons.brightness_low_rounded;
    } else {
      icon = value > 0.6
          ? Icons.volume_up_rounded
          : value > 0.0
              ? Icons.volume_down_rounded
              : Icons.volume_off_rounded;
    }

    final color = isBrightness
        ? const Color(0xFFFFE066)
        : const Color(0xFF66AAFF);

    return Align(
      alignment: isBrightness ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: 44,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            // Vertical bar — fixed height pill, consistent between both
            SizedBox(
              width: 4,
              height: 90,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: RotatedBox(
                  quarterTurns: -1,
                  child: LinearProgressIndicator(
                    value: value.clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
