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
  double _baseZoomScale = 1.0;
  double _dragStartDx = 0;
  bool _swipeActive = false;
  bool _isPinching = false;
  bool _postPinchCooldown = false;
  double _dragStartDy = 0;
  bool _swipeCommitted = false;
  bool _isSeekSwipe = false;
  double _seekStartProgress = 0;

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
    _notifier.dispose();
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
        useSafeArea: true,
        showDragHandle: false,
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
            final (:isLocked, :lockIconVisible, :controlsVisible) =
                ref.watch(playerProvider.select((s) => (
                  isLocked: s.isLocked,
                  lockIconVisible: s.lockIconVisible,
                  controlsVisible: s.controlsVisible,
                )));

            return Stack(
              children: [
                // ── Video + all non-lock overlays (never re-built by lock) ──
                child!,

                // ── Seek flash overlays ──────────────────────────────────────
                if (_seekFlashLeft)
                  Positioned(
                    left: 0, top: 0, bottom: 0,
                    width: size.width / 2,
                    child: SeekFlash(animation: _seekFlashAnim, isForward: false),
                  ),
                if (_seekFlashRight)
                  Positioned(
                    right: 0, top: 0, bottom: 0,
                    width: size.width / 2,
                    child: SeekFlash(animation: _seekFlashAnim, isForward: true),
                  ),

                // ── Main gesture layer — disabled when locked ────────────────
                // Always present in the Stack so sibling indices never shift.
                // IgnorePointer disables it instead of removing it, which
                // prevents the Video platform view from being re-composited.
                IgnorePointer(
                  ignoring: isLocked,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (!_swipeActive && !_isPinching) {
                        controlsVisible
                            ? _notifier.hideControls()
                            : _notifier.showControls();
                      }
                    },
                    onDoubleTapDown: (details) {
                      final isLeft = details.globalPosition.dx < size.width / 2;
                      if (isLeft) {
                        _notifier.seekRelative(-10);
                      } else {
                        _notifier.seekRelative(10);
                      }
                      _triggerSeekFlash(isLeft);
                    },
                    onScaleStart: (details) {
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
                            _notifier.endSeek(ref.read(playerProvider).seekValue);
                          } else {
                            _notifier.endSwipe();
                          }
                        }
                      }
                    },
                    child: const SizedBox.expand(),
                  ),
                ),

                // ── Lock touch-absorber — always present, opaque when locked ──
                // Sits above the gesture layer. When locked, absorbs all touches
                // and shows the lock icon on tap. When unlocked, lets touches
                // pass through to the gesture layer above (in hit-test order).
                // Never added/removed — IgnorePointer toggles it — so the Video
                // platform view is never re-composited.
                IgnorePointer(
                  ignoring: !isLocked,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _notifier.showLockIcon,
                    // Absorb all scale events so no gesture leaks through.
                    onScaleStart: (_) {},
                    onScaleUpdate: (_) {},
                    onScaleEnd: (_) {},
                    child: const SizedBox.expand(),
                  ),
                ),

                // ── Lock icon overlay — always present, fades in/out ─────────
                // AnimatedOpacity keeps the same widget type at all times so
                // Flutter never tears down and rebuilds this subtree, which
                // would re-composite the Video platform view beneath it.
                // Duration.zero when hiding = instant disappear, no flash.
                AnimatedOpacity(
                  opacity: (isLocked && lockIconVisible) ? 1.0 : 0.0,
                  duration: (isLocked && lockIconVisible)
                      ? const Duration(milliseconds: 200)
                      : Duration.zero,
                  child: IgnorePointer(
                    // Only hittable when fully visible and locked.
                    ignoring: !(isLocked && lockIconVisible),
                    child: LockOverlay(
                      onUnlock: _notifier.toggleLock,
                    ),
                  ),
                ),
              ],
            );
          },
          // ── child — Video + non-lock overlays, rebuilt only by their own ──
          // state. Passed as the Consumer `child` argument so it is created
          // once and reused across Consumer rebuilds triggered by lock state.
          child: Stack(
            children: [
              // ── Video ────────────────────────────────────────────────────
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
                      ref.read(playerProvider.notifier).videoController == null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return Positioned.fill(
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

              // ── Swipe HUD ────────────────────────────────────────────────
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

              // ── Auto-play countdown ──────────────────────────────────────
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

              // ── Zoom indicator — tap to reset ────────────────────────────
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
                            color: const Color(0xA6000000),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0x33FFFFFF), width: 1),
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

              // ── Controls overlay ─────────────────────────────────────────
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

                  final visible = controlsVisible && !isLocked;
                  return AnimatedOpacity(
                    opacity: visible ? 1.0 : 0.0,
                    duration: visible
                        ? const Duration(milliseconds: 200)
                        : Duration.zero,
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
                        onToggleFullscreen: notifier.cycleRotationMode,
                        onSeekStart: notifier.beginSeek,
                        onSeekUpdate: notifier.updateSeek,
                        onSeekEnd: notifier.endSeek,
                        onPlayNext: notifier.playNext,
                        onPlayPrevious: notifier.playPrevious,
                        onToggleLock: notifier.toggleLock,
                        onToggleRepeat: notifier.cycleLoopMode,
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
