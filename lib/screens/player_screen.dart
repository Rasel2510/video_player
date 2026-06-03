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
  // ── Seek flash ─────────────────────────────────────────────────────────────
  late final AnimationController _seekFlashCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _seekFlashAnim = CurvedAnimation(
    parent: _seekFlashCtrl,
    curve: Curves.easeOut,
  );
  bool _seekFlashLeft  = false;
  bool _seekFlashRight = false;

  // ── Scale / pinch-to-zoom ──────────────────────────────────────────────────
  // We handle all pointer gestures through onScale* so that single-finger
  // vertical swipes (brightness / volume) and two-finger pinch share one
  // recogniser without conflicting.
  double _baseZoomScale = 1.0;
  double _dragStartDx   = 0;
  bool   _swipeActive   = false;
  bool   _isPinching    = false;
  // FIX: after a pinch ends, ignore the stray single-finger events that fire
  // as the second finger lifts — they would otherwise trigger a brightness/
  // volume swipe unintentionally.
  bool   _postPinchCooldown = false;

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
    ref.read(playerProvider.notifier).dispose();
    super.dispose();
  }

  // ── Seek flash ─────────────────────────────────────────────────────────────

  void _triggerSeekFlash(bool isLeft) {
    setState(() {
      _seekFlashLeft  = isLeft;
      _seekFlashRight = !isLeft;
    });
    _seekFlashCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() { _seekFlashLeft = false; _seekFlashRight = false; });
    });
  }

  // ── Sheet helpers ──────────────────────────────────────────────────────────

  void _showSpeedSheet(BuildContext ctx, double speed) =>
      showModalBottomSheet(
        context: ctx,
        builder: (_) => SpeedSheet(
          currentSpeed: speed,
          onSelect: (s) => ref.read(playerProvider.notifier).setSpeed(s),
        ),
      );

  void _showVolumeSheet(BuildContext ctx, double volume) =>
      showModalBottomSheet(
        context: ctx,
        builder: (_) => VolumeSheet(
          volume: volume,
          onChanged: (v) => ref.read(playerProvider.notifier).setVolume(v),
        ),
      );

  void _showAudioTrackSheet(BuildContext ctx) {
    final s = ref.read(playerProvider);
    showModalBottomSheet(
      context: ctx,
      builder: (_) => AudioTrackSheet(
        tracks: s.audioTracks,
        selectedTrack: s.selectedAudioTrack,
        onSelect: (t) => ref.read(playerProvider.notifier).setAudioTrack(t),
      ),
    );
  }

  void _showSubtitleSheet(BuildContext ctx) {
    final s = ref.read(playerProvider);
    showModalBottomSheet(
      context: ctx,
      builder: (_) => SubtitleSheet(
        tracks: s.subtitleTracks,
        selectedTrack: s.selectedSubtitleTrack,
        subtitlesEnabled: s.subtitlesEnabled,
        onSelect: (t) => ref.read(playerProvider.notifier).setSubtitleTrack(t),
        onToggle: () => ref.read(playerProvider.notifier).toggleSubtitles(),
      ),
    );
  }

  // ── Fit mode ───────────────────────────────────────────────────────────────

  BoxFit _boxFit(FitMode mode) => switch (mode) {
        FitMode.contain => BoxFit.contain,
        FitMode.cover   => BoxFit.cover,
        FitMode.fill    => BoxFit.fill,
        FitMode.natural => BoxFit.scaleDown,
      };

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(playerProvider.notifier);
    final size     = MediaQuery.of(context).size;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await ref.read(playerProvider.notifier).dispose();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer(
          builder: (context, ref, child) {
            final isLocked      = ref.watch(playerProvider.select((s) => s.isLocked));
            final controlsVisible =
                ref.watch(playerProvider.select((s) => s.controlsVisible));

            return Stack(
              children: [
                // ── Gesture layer (disabled when locked) ──────────────────
                IgnorePointer(
                  ignoring: isLocked,
                  child: GestureDetector(
                    onTap: () {
                      if (!_swipeActive && !_isPinching) {
                        controlsVisible
                            ? notifier.hideControls()
                            : notifier.showControls();
                      }
                    },
                    onDoubleTapDown: (details) {
                      final isLeft = details.globalPosition.dx < size.width / 2;
                      if (isLeft) notifier.seekRelative(-10);
                      else        notifier.seekRelative(10);
                      _triggerSeekFlash(isLeft);
                    },
                    // ── Scale gesture handles both single-finger swipes
                    //    (brightness/volume) and two-finger pinch-to-zoom. ──
                    onScaleStart: (details) {
                      if (details.pointerCount >= 2) {
                        _isPinching       = true;
                        _swipeActive      = false;
                        _postPinchCooldown = false;
                        _baseZoomScale =
                            ref.read(playerProvider).zoomScale;
                      } else {
                        // FIX: skip single-finger start right after pinch lifts
                        if (_postPinchCooldown) return;
                        _isPinching  = false;
                        _dragStartDx = details.localFocalPoint.dx;
                        _swipeActive = true;
                        notifier.startSwipe(_dragStartDx, size.width);
                      }
                    },
                    onScaleUpdate: (details) {
                      if (_isPinching || details.pointerCount >= 2) {
                        _isPinching  = true;
                        _swipeActive = false;
                        notifier.setZoomScale(
                            _baseZoomScale * details.scale);
                      } else if (_swipeActive && !_postPinchCooldown) {
                        notifier.updateSwipe(
                            details.focalPointDelta.dy, size.height);
                      }
                    },
                    onScaleEnd: (_) {
                      if (_isPinching) {
                        _isPinching        = false;
                        _postPinchCooldown = true;
                        // Clear the cooldown after the finger-lift window passes.
                        Future.delayed(
                          const Duration(milliseconds: 150),
                          () => _postPinchCooldown = false,
                        );
                      } else if (_swipeActive) {
                        _swipeActive = false;
                        notifier.endSwipe();
                      }
                    },
                    child: child,
                  ),
                ),

                // ── Lock overlay (always interactive when locked) ──────────
                if (isLocked)
                  _LockOverlay(onUnlock: notifier.toggleLock),
              ],
            );
          },
          child: Stack(
            children: [
              // ── Video ──────────────────────────────────────────────────
              Consumer(
                builder: (context, ref, _) {
                  final isInitialized =
                      ref.watch(playerProvider.select((s) => s.isInitialized));
                  final fitMode =
                      ref.watch(playerProvider.select((s) => s.fitMode));
                  final zoomScale =
                      ref.watch(playerProvider.select((s) => s.zoomScale));
                  final hasError =
                      ref.watch(playerProvider.select((s) => s.hasError));
                  final errorMsg =
                      ref.watch(playerProvider.select((s) => s.errorMessage));

                  if (hasError) {
                    return _ErrorState(
                      message: errorMsg,
                      onRetry: () => ref.read(playerProvider.notifier).init(
                            ref.read(playerProvider).currentVideo?.path ??
                                '',
                            folderVideos:
                                ref.read(playerProvider).folderVideos,
                            initialIndex:
                                ref.read(playerProvider).currentIndex,
                          ),
                      onBack: () => Navigator.pop(context),
                    );
                  }

                  if (!isInitialized ||
                      ref.read(playerProvider.notifier).videoController ==
                          null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return Positioned.fill(
                    child: Transform.scale(
                      scale: zoomScale,
                      child: Video(
                        controller: ref
                            .read(playerProvider.notifier)
                            .videoController!,
                        fit: _boxFit(fitMode),
                        controls: NoVideoControls,
                      ),
                    ),
                  );
                },
              ),

              // ── Seek flash overlays ────────────────────────────────────
              if (_seekFlashLeft)
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  width: MediaQuery.of(context).size.width / 2,
                  child: _SeekFlash(animation: _seekFlashAnim, isForward: false),
                ),
              if (_seekFlashRight)
                Positioned(
                  right: 0, top: 0, bottom: 0,
                  width: MediaQuery.of(context).size.width / 2,
                  child: _SeekFlash(animation: _seekFlashAnim, isForward: true),
                ),

              // ── Swipe HUD ──────────────────────────────────────────────
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

              // ── Auto-play countdown ────────────────────────────────────
              Consumer(
                builder: (context, ref, _) {
                  final countdown = ref.watch(
                      playerProvider.select((s) => s.autoPlayCountdown));
                  final nextVideo =
                      ref.watch(playerProvider.select((s) => s.nextVideo));
                  if (countdown == null || nextVideo == null) {
                    return const SizedBox();
                  }
                  return _AutoPlayCountdown(
                    countdown: countdown,
                    nextVideoName: nextVideo.name,
                    onCancel: () =>
                        ref.read(playerProvider.notifier).cancelAutoPlay(),
                    onPlayNow: () =>
                        ref.read(playerProvider.notifier).playNext(),
                  );
                },
              ),

              // ── Zoom indicator — tap to reset ──────────────────────────
              Consumer(
                builder: (context, ref, _) {
                  final zoom = ref.watch(
                      playerProvider.select((s) => s.zoomScale));
                  if ((zoom - 1.0).abs() < 0.05) return const SizedBox();
                  return Positioned(
                    top: 60,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () =>
                            ref.read(playerProvider.notifier).resetZoom(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.zoom_in_rounded,
                                  color: Colors.white70, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '${zoom.toStringAsFixed(1)}×',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.close_rounded,
                                  color: Colors.white54, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ── Controls overlay ───────────────────────────────────────
              Consumer(
                builder: (context, ref, _) {
                  final isInitialized =
                      ref.watch(playerProvider.select((s) => s.isInitialized));
                  final isLocked =
                      ref.watch(playerProvider.select((s) => s.isLocked));
                  final hasError =
                      ref.watch(playerProvider.select((s) => s.hasError));
                  if (!isInitialized || isLocked || hasError) {
                    return const SizedBox();
                  }
                  final controlsVisible = ref
                      .watch(playerProvider.select((s) => s.controlsVisible));
                  final currentVideo =
                      ref.watch(playerProvider.select((s) => s.currentVideo));
                  final displayName = currentVideo?.name ?? widget.fileName;
                  final notifier = ref.read(playerProvider.notifier);

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
                        onToggleLock: notifier.toggleLock,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Lock overlay ──────────────────────────────────────────────────────────────

class _LockOverlay extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockOverlay({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: GestureDetector(
              onTap: onUnlock,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25), width: 1),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Auto-play countdown overlay ───────────────────────────────────────────────

class _AutoPlayCountdown extends StatelessWidget {
  final int countdown;
  final String nextVideoName;
  final VoidCallback onCancel;
  final VoidCallback onPlayNow;

  const _AutoPlayCountdown({
    required this.countdown,
    required this.nextVideoName,
    required this.onCancel,
    required this.onPlayNow,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12), width: 1),
        ),
        child: Row(
          children: [
            // Countdown ring
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: countdown / 5.0,
                    strokeWidth: 2.5,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF6C8EFF)),
                    backgroundColor: Colors.white12,
                  ),
                  Text(
                    '$countdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Up next',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nextVideoName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Play Now button
            GestureDetector(
              onTap: onPlayNow,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C8EFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Play',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Cancel button
            GestureDetector(
              onTap: onCancel,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ErrorState({this.message, required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFF2A1010),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 30, color: Color(0xFFFF5C5C)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to play video',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Go back'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C8EFF),
                    shape: const StadiumBorder(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Seek flash widget ─────────────────────────────────────────────────────────

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
    final percent = '${(value * 100).round()}%';

    return Align(
      alignment: isBrightness ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: 44,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.10), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            Text(
              percent,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
