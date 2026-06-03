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
  bool _seekFlashLeft = false;
  bool _seekFlashRight = false;

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
        FitMode.cover => BoxFit.cover,
        FitMode.fill => BoxFit.fill,
        FitMode.natural => BoxFit.scaleDown,
      };

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(playerProvider.notifier);
    final size = MediaQuery.of(context).size;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await ref.read(playerProvider.notifier).dispose();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer(
          builder: (context, ref, child) {
            final isLocked =
                ref.watch(playerProvider.select((s) => s.isLocked));
            final lockIconVisible =
                ref.watch(playerProvider.select((s) => s.lockIconVisible));
            final controlsVisible =
                ref.watch(playerProvider.select((s) => s.controlsVisible));

            return Stack(
              children: [
                // ── Main gesture layer (only active when NOT locked) ──────────
                GestureDetector(
                  onTap: () {
                    if (!_swipeActive && !_isPinching) {
                      controlsVisible
                          ? notifier.hideControls()
                          : notifier.showControls();
                    }
                  },
                  onDoubleTapDown: (details) {
                    if (isLocked) return;
                    final isLeft = details.globalPosition.dx < size.width / 2;
                    if (isLeft) {
                      notifier.seekRelative(-10);
                    } else {
                      notifier.seekRelative(10);
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
                        notifier.setZoomScale(_baseZoomScale * details.scale);
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
                            notifier.beginSeek(_seekStartProgress);
                            notifier.showControls();
                          } else {
                            _isSeekSwipe = false;
                            notifier.startSwipe(_dragStartDx, size.width);
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
                          notifier.updateSeek(newMs / durationMs);
                        }
                      } else {
                        notifier.updateSwipe(
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
                          notifier.endSeek(
                              ref.read(playerProvider).seekValue);
                        } else {
                          notifier.endSwipe();
                        }
                      }
                    }
                  },
                  child: child,
                ),

                // ── Lock overlay — always absorbs touches when locked ─────────
                // Using a separate full-screen GestureDetector (not toggling
                // callbacks to null) means the Video texture never rebuilds.
                if (isLocked)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: notifier.showLockIcon,
                      // absorb all other gestures silently
                      onScaleStart: (_) {},
                      onScaleUpdate: (_) {},
                      onScaleEnd: (_) {},
                      child: const SizedBox.expand(),
                    ),
                  ),

                // ── Lock icon (visible for 3 s, then hides) ──────────────────
                if (isLocked && lockIconVisible)
                  LockOverlay(onUnlock: notifier.toggleLock),
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
                    return ErrorState(
                      message: errorMsg,
                      onRetry: () => ref.read(playerProvider.notifier).init(
                            ref.read(playerProvider).currentVideo?.path ?? '',
                            folderVideos: ref.read(playerProvider).folderVideos,
                            initialIndex: ref.read(playerProvider).currentIndex,
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
                        controller:
                            ref.read(playerProvider.notifier).videoController!,
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
                  final gesture =
                      ref.watch(playerProvider.select((s) => s.swipeGesture));
                  final value =
                      ref.watch(playerProvider.select((s) => s.swipeValue));
                  if (gesture == SwipeGesture.none) return const SizedBox();
                  return SwipeHud(gesture: gesture, value: value);
                },
              ),

              // ── Auto-play countdown ────────────────────────────────────
              Consumer(
                builder: (context, ref, _) {
                  final countdown = ref
                      .watch(playerProvider.select((s) => s.autoPlayCountdown));
                  final nextVideo =
                      ref.watch(playerProvider.select((s) => s.nextVideo));
                  if (countdown == null || nextVideo == null) {
                    return const SizedBox();
                  }
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
              Consumer(
                builder: (context, ref, _) {
                  final zoom =
                      ref.watch(playerProvider.select((s) => s.zoomScale));
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
                  final hasError =
                      ref.watch(playerProvider.select((s) => s.hasError));
                  if (!isInitialized || hasError) {
                    return const SizedBox();
                  }
                  final isLocked =
                      ref.watch(playerProvider.select((s) => s.isLocked));
                  final controlsVisible = ref
                      .watch(playerProvider.select((s) => s.controlsVisible));
                  final currentVideo =
                      ref.watch(playerProvider.select((s) => s.currentVideo));
                  final displayName = currentVideo?.name ?? widget.fileName;
                  final notifier = ref.read(playerProvider.notifier);

                  // Keep controls in the widget tree when locked (opacity=0)
                  // so that Flutter never tears down compositing layers,
                  // which would cause the Video platform texture to flash black.
                  final visible = controlsVisible && !isLocked;
                  return AnimatedOpacity(
                    opacity: visible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
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

