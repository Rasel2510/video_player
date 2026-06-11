import 'dart:async';
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
import '../presentation/widgets/player/lock_overlay.dart';
import '../presentation/widgets/player/auto_play_countdown.dart';
import '../presentation/widgets/player/error_state.dart';
import '../presentation/widgets/player/seek_flash.dart';
import '../presentation/widgets/player/swipe_hud.dart';

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
    with TickerProviderStateMixin {
  // ── Seek flash ─────────────────────────────────────────────────────────────
  late final AnimationController _seekFlashCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _seekFlashAnim = CurvedAnimation(
    parent: _seekFlashCtrl,
    curve: Curves.easeOut,
  );
  bool _seekFlashLeft = false;
  bool _seekFlashRight = false;

  // ── Lock icon animation ────────────────────────────────────────────────────
  // Driven locally so showing/hiding the lock icon never triggers a state
  // update → no Consumer rebuild → no platform-view re-composite → no white flash.
  late final AnimationController _lockIconCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  Timer? _lockIconLocalTimer;

  // ── Scale / pinch-to-zoom ──────────────────────────────────────────────────
  // We handle all pointer gestures through onScale* so that single-finger
  // vertical swipes (brightness / volume) and two-finger pinch share one
  // recogniser without conflicting.
  double _baseZoomScale = 1.0;
  double _dragStartDx = 0;
  bool _swipeActive = false;
  bool _isPinching = false;
  // FIX: after a pinch ends, ignore the stray single-finger events that fire
  // as the second finger lifts — they would otherwise trigger a brightness/
  // volume swipe unintentionally.
  bool _postPinchCooldown = false;
  
  double _dragStartDy = 0;
  bool _swipeCommitted = false;
  bool _isSeekSwipe = false;
  double _seekStartProgress = 0;

  // Convenience getter — ref.read(playerProvider.notifier) repeated in build()
  // is equivalent each call (provider identity is stable), but a getter makes
  // the intent clear and avoids typos.
  PlayerNotifier get _notifier => ref.read(playerProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifier.init(
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
    _lockIconCtrl.dispose();
    _lockIconLocalTimer?.cancel();
    _notifier.dispose();
    super.dispose();
  }

  // ── Lock icon helpers ──────────────────────────────────────────────────────

  /// Show the lock icon using a local AnimationController — never updates
  /// provider state — so the Video platform view is never re-composited.
  void _showLockIconLocal() {
    _lockIconCtrl.forward();
    _lockIconLocalTimer?.cancel();
    _lockIconLocalTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _lockIconCtrl.reverse();
    });
  }

  void _hideLockIconLocal() {
    _lockIconLocalTimer?.cancel();
    _lockIconCtrl.reverse();
  }

  // ── Seek flash ─────────────────────────────────────────────────────────────

  void _triggerSeekFlash(bool isLeft) {
    setState(() {
      _seekFlashLeft = isLeft;
      _seekFlashRight = !isLeft;
    });
    _seekFlashCtrl.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _seekFlashLeft = false;
          _seekFlashRight = false;
        });
      }
    });
  }

  // ── Sheet helpers ──────────────────────────────────────────────────────────

  void _showSpeedSheet(BuildContext ctx, double speed) => showModalBottomSheet(
        context: ctx,
        useSafeArea: true,
        // Prevent Flutter from drawing its own system drag handle on top of
        // the sheet's built-in handle, which caused a double-bar appearance.
        showDragHandle: false,
        // The sheet Container already has its own rounded background colour.
        // Without this, the Modal's default white/surface background bleeds
        // through the rounded corners making the sheet look semi-transparent.
        backgroundColor: Colors.transparent,
        builder: (_) => SpeedSheet(
          currentSpeed: speed,
          onSelect: (s) => _notifier.setSpeed(s),
        ),
      );

  void _showVolumeSheet(BuildContext ctx, double volume) =>
      showModalBottomSheet(
        context: ctx,
        useSafeArea: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (_) => VolumeSheet(
          volume: volume,
          onChanged: (v) => _notifier.setVolume(v),
        ),
      );

  void _showAudioTrackSheet(BuildContext ctx) {
    final s = ref.read(playerProvider);
    showModalBottomSheet(
      context: ctx,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => AudioTrackSheet(
        tracks: s.audioTracks,
        selectedTrack: s.selectedAudioTrack,
        onSelect: (t) => _notifier.setAudioTrack(t),
      ),
    );
  }

  void _showSubtitleSheet(BuildContext ctx) {
    final s = ref.read(playerProvider);
    showModalBottomSheet(
      context: ctx,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => SubtitleSheet(
        tracks: s.subtitleTracks,
        selectedTrack: s.selectedSubtitleTrack,
        subtitlesEnabled: s.subtitlesEnabled,
        onSelect: (t) => _notifier.setSubtitleTrack(t),
        onToggle: () => _notifier.toggleSubtitles(),
      ),
    );
  }

  // ── Fit mode ───────────────────────────────────────────────────────────────
  // Const map avoids a switch allocation on every video Consumer rebuild.
  static const _fitBoxMap = {
    FitMode.contain: BoxFit.contain,
    FitMode.cover:   BoxFit.cover,
    FitMode.fill:    BoxFit.fill,
    FitMode.natural: BoxFit.scaleDown,
  };
  BoxFit _boxFit(FitMode mode) => _fitBoxMap[mode] ?? BoxFit.contain;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await _notifier.dispose();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer(
          builder: (context, ref, child) {
            // Watch only isLocked + controlsVisible.
            // lockIconVisible is intentionally NOT watched here — its
            // show/hide is driven by _lockIconCtrl (an AnimationController
            // local to this State) so it never triggers a Consumer rebuild
            // and therefore never re-composites the Video platform view.
            final (:isLocked, :controlsVisible) =
                ref.watch(playerProvider.select((s) => (
                  isLocked: s.isLocked,
                  controlsVisible: s.controlsVisible,
                )));

            return Stack(
              children: [
                // ── Main gesture layer (only active when NOT locked) ──────────
                GestureDetector(
                  onTap: () {
                    if (!_swipeActive && !_isPinching) {
                      controlsVisible
                          ? _notifier.hideControls()
                          : _notifier.showControls();
                    }
                  },
                  onDoubleTapDown: (details) {
                    if (isLocked) return;
                    final isLeft = details.globalPosition.dx < size.width / 2;
                    if (isLeft) {
                      _notifier.seekRelative(-10);
                    } else {
                      _notifier.seekRelative(10);
                    }
                    _triggerSeekFlash(isLeft);
                  },
                  onScaleStart: (details) {
                    if (isLocked) return;
                    if (details.pointerCount >= 2) {
                      _isPinching = true;
                      _swipeActive = false;
                      _postPinchCooldown = false;
                      _baseZoomScale = ref.read(playerProvider).zoomScale;
                    } else {
                      if (_postPinchCooldown) return;
                      _isPinching = false;
                      _dragStartDx = details.localFocalPoint.dx;
                      _dragStartDy = details.localFocalPoint.dy;
                      _swipeActive = true;
                      _swipeCommitted = false;
                      _isSeekSwipe = false;
                    }
                  },
                  onScaleUpdate: (details) {
                    if (isLocked) return;
                    if (_isPinching || details.pointerCount >= 2) {
                      _isPinching = true;
                      _swipeActive = false;
                      if (details.pointerCount >= 2) {
                        _notifier.setZoomScale(_baseZoomScale * details.scale);
                      }
                    } else if (_swipeActive && !_postPinchCooldown) {
                      if (!_swipeCommitted) {
                        final dx = details.localFocalPoint.dx - _dragStartDx;
                        final dy = details.localFocalPoint.dy - _dragStartDy;
                        if (dx.abs() > 15 || dy.abs() > 15) {
                          _swipeCommitted = true;
                          if (dx.abs() > dy.abs()) {
                            _isSeekSwipe = true;
                            _seekStartProgress = ref.read(playerProvider).progress;
                            _notifier.beginSeek(_seekStartProgress);
                            _notifier.showControls();
                          } else {
                            _isSeekSwipe = false;
                            _notifier.startSwipe(_dragStartDx, size.width);
                          }
                        } else {
                          return;
                        }
                      }
                      if (_isSeekSwipe) {
                        final durationMs =
                            ref.read(playerProvider).duration.inMilliseconds;
                        if (durationMs > 0) {
                          final deltaMs =
                              (details.localFocalPoint.dx - _dragStartDx) * 300;
                          final seekStartMs = _seekStartProgress * durationMs;
                          final newMs = (seekStartMs + deltaMs)
                              .clamp(0.0, durationMs.toDouble());
                          _notifier.updateSeek(newMs / durationMs);
                        }
                      } else {
                        _notifier.updateSwipe(
                            details.focalPointDelta.dy, size.height);
                      }
                    }
                  },
                  onScaleEnd: (_) {
                    if (isLocked) return;
                    if (_isPinching) {
                      _isPinching = false;
                      _postPinchCooldown = true;
                      Future.delayed(
                        const Duration(milliseconds: 150),
                        () => _postPinchCooldown = false,
                      );
                    } else if (_swipeActive) {
                      _swipeActive = false;
                      if (_swipeCommitted) {
                        if (_isSeekSwipe) {
                          _notifier.endSeek(
                              ref.read(playerProvider).seekValue);
                        } else {
                          _notifier.endSwipe();
                        }
                      }
                    }
                  },
                  child: child,
                ),

                // ── Lock touch-absorber — always in tree, active only when locked ──
                // IgnorePointer switches touch-absorption without adding/removing
                // siblings, so the Video platform view is never re-composited.
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !isLocked,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // When the locked screen is tapped, show the lock icon
                      // via _lockIconCtrl — a purely local animation that never
                      // updates provider state and therefore causes zero rebuilds
                      // (and zero white flashes on the video layer).
                      onTap: isLocked ? _showLockIconLocal : null,
                      onScaleStart: (_) {},
                      onScaleUpdate: (_) {},
                      onScaleEnd: (_) {},
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),

                // ── Lock icon — driven by local AnimationController ───────────
                // FadeTransition + AnimationController never touches provider
                // state, so no Consumer rebuilds, no platform-view re-composite,
                // no white flash when the icon appears/disappears.
                Positioned.fill(
                  child: FadeTransition(
                    opacity: _lockIconCtrl,
                    child: AnimatedBuilder(
                      animation: _lockIconCtrl,
                      builder: (context, child) => IgnorePointer(
                        // Pass taps through when hidden so the touch-absorber
                        // can show the icon on the next tap.
                        ignoring: !isLocked || _lockIconCtrl.value == 0,
                        child: child,
                      ),
                      child: LockOverlay(
                        onUnlock: () {
                          _hideLockIconLocal();
                          _notifier.toggleLock();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: Stack(
            children: [
              // ── Video ──────────────────────────────────────────────────
              Consumer(
                builder: (context, ref, _) {
                  final (:isInitialized, :fitMode, :zoomScale, :hasError, errorMsg: errorMsg) =
                      ref.watch(playerProvider.select((s) => (
                            isInitialized: s.isInitialized,
                            fitMode:       s.fitMode,
                            zoomScale:     s.zoomScale,
                            hasError:      s.hasError,
                            errorMsg:      s.errorMessage,
                          )));

                  if (hasError) {
                    return ErrorState(
                      message: errorMsg,
                      onRetry: () {
                        // FIX #OPT-1: .let() is a Kotlin idiom; Dart has no such
                        // built-in extension. Use a plain block instead.
                        final n = ref.read(playerProvider.notifier);
                        final s = ref.read(playerProvider);
                        n.init(
                          s.currentVideo?.path ?? '',
                          folderVideos: s.folderVideos,
                          initialIndex: s.currentIndex,
                        );
                      },
                      onBack: () => Navigator.pop(context),
                    );
                  }

                  if (!isInitialized ||
                      ref.read(playerProvider.notifier).videoController ==
                          null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return Positioned.fill(
                    // FIX #OPT-11: Transform.scale at 1.0 still composites an
                    // extra layer. Skip the wrapper entirely when not zoomed.
                    child: zoomScale == 1.0
                        ? Video(
                            controller: ref
                                .read(playerProvider.notifier)
                                .videoController!,
                            fit: _boxFit(fitMode),
                            controls: NoVideoControls,
                          )
                        : Transform.scale(
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
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width / 2,
                  child:
                      SeekFlash(animation: _seekFlashAnim, isForward: false),
                ),
              if (_seekFlashRight)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width / 2,
                  child: SeekFlash(animation: _seekFlashAnim, isForward: true),
                ),

              // ── Swipe HUD ──────────────────────────────────────────────
              Consumer(
                builder: (context, ref, _) {
                  final (:gesture, :value) =
                      ref.watch(playerProvider.select((s) => (
                            gesture: s.swipeGesture,
                            value:   s.swipeValue,
                          )));
                  if (gesture == SwipeGesture.none) return const SizedBox();
                  return SwipeHud(gesture: gesture, value: value);
                },
              ),

              // ── Auto-play countdown ────────────────────────────────────
              Consumer(
                builder: (context, ref, _) {
                  final (:countdown, :nextVideo) =
                      ref.watch(playerProvider.select((s) => (
                            countdown: s.autoPlayCountdown,
                            nextVideo: s.nextVideo,
                          )));
                  if (countdown == null || nextVideo == null) return const SizedBox();
                  return AutoPlayCountdown(
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
              const _ZoomIndicatorOverlay(),

              // ── Controls overlay ───────────────────────────────────────
              Consumer(
                builder: (context, ref, _) {
                  final (:isInitialized, :hasError, :isLocked,
                          :controlsVisible, :currentVideo) =
                      ref.watch(playerProvider.select((s) => (
                            isInitialized:   s.isInitialized,
                            hasError:        s.hasError,
                            isLocked:        s.isLocked,
                            controlsVisible: s.controlsVisible,
                            currentVideo:    s.currentVideo,
                          )));
                  if (!isInitialized || hasError) return const SizedBox();
                  final displayName = currentVideo?.name ?? widget.fileName;
                  final notifier = ref.read(playerProvider.notifier);

                  // Keep controls in the widget tree when hidden (opacity=0)
                  // so Flutter never tears down the platform-view compositor layer.
                  //
                  // IMPORTANT: always use the SAME widget type (AnimatedOpacity)
                  // regardless of visibility. Switching between AnimatedOpacity
                  // and Opacity causes Flutter to rebuild the subtree, which
                  // triggers a white compositor-layer flash over the video
                  // platform view in release builds — the exact "white screen"
                  // seen when tapping the lock icon.
                  //
                  // Using Duration.zero when hiding gives an instant hide
                  // without any intermediate saveLayer, while keeping the widget
                  // type stable avoids the destructive rebuild entirely.
                  final visible = controlsVisible && !isLocked;
                  final child = IgnorePointer(
                    ignoring: !visible,
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
                        onToggleFullscreen: notifier.cycleRotationMode,
                        onSeekStart: notifier.beginSeek,
                        onSeekUpdate: notifier.updateSeek,
                        onSeekEnd: notifier.endSeek,
                        onPlayNext: notifier.playNext,
                        onPlayPrevious: notifier.playPrevious,
                        onToggleLock: () {
                          // When locking: show the lock icon locally so the
                          // user knows the screen is now locked, then auto-hide.
                          // When unlocking: the LockOverlay.onUnlock callback
                          // already called _hideLockIconLocal + toggleLock.
                          final willLock = !ref.read(playerProvider).isLocked;
                          notifier.toggleLock();
                          if (willLock) _showLockIconLocal();
                        },
                        onToggleRepeat: notifier.cycleLoopMode,
                      ),
                    );
                  return AnimatedOpacity(
                    opacity: visible ? 1.0 : 0.0,
                    // Fade-in when showing; instant (0 ms) when hiding so there
                    // is no intermediate compositor layer to flash white.
                    duration: visible
                        ? const Duration(milliseconds: 200)
                        : Duration.zero,
                    child: child,
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

class _ZoomIndicatorOverlay extends ConsumerStatefulWidget {
  const _ZoomIndicatorOverlay();

  @override
  ConsumerState<_ZoomIndicatorOverlay> createState() => _ZoomIndicatorOverlayState();
}

class _ZoomIndicatorOverlayState extends ConsumerState<_ZoomIndicatorOverlay> {
  Timer? _timer;
  bool _visible = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showIndicator() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _visible = true;
    });
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _visible = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final zoom = ref.watch(playerProvider.select((s) => s.zoomScale));

    ref.listen<double>(
      playerProvider.select((s) => s.zoomScale),
      (previous, next) {
        if ((next - 1.0).abs() < 0.05) {
          _timer?.cancel();
          if (_visible) {
            setState(() {
              _visible = false;
            });
          }
        } else if (previous != next) {
          _showIndicator();
        }
      },
    );

    final show = _visible && (zoom - 1.0).abs() >= 0.05;

    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !show,
            child: GestureDetector(
              onTap: () {
                ref.read(playerProvider.notifier).resetZoom();
                _timer?.cancel();
                setState(() {
                  _visible = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xA6000000),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0x33FFFFFF),
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
        ),
      ),
    );
  }
}


