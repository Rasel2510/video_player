import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/player_provider.dart';
import 'seek_flash.dart';

class PlayerGestureLayer extends ConsumerStatefulWidget {
  final Widget child;

  const PlayerGestureLayer({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<PlayerGestureLayer> createState() => _PlayerGestureLayerState();
}

class _PlayerGestureLayerState extends ConsumerState<PlayerGestureLayer>
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

  @override
  void dispose() {
    _seekFlashCtrl.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final (:isLocked, :controlsVisible) = ref.watch(playerProvider.select((s) => (
      isLocked: s.isLocked,
      controlsVisible: s.controlsVisible,
    )));

    return Stack(
      children: [
        // Gesture layer
        GestureDetector(
          onTap: () {
            if (!_swipeActive && !_isPinching) {
              controlsVisible
                  ? ref.read(playerProvider.notifier).hideControls()
                  : ref.read(playerProvider.notifier).showControls();
            }
          },
          onDoubleTapDown: (details) {
            if (isLocked) return;
            final isLeft = details.globalPosition.dx < size.width / 2;
            if (isLeft) {
              ref.read(playerProvider.notifier).seekRelative(-10);
            } else {
              ref.read(playerProvider.notifier).seekRelative(10);
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
                ref.read(playerProvider.notifier).setZoomScale(_baseZoomScale * details.scale);
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
                    ref.read(playerProvider.notifier).beginSeek(_seekStartProgress);
                    ref.read(playerProvider.notifier).showControls();
                  } else {
                    _isSeekSwipe = false;
                    ref.read(playerProvider.notifier).startSwipe(_dragStartDx, size.width);
                  }
                } else {
                  return;
                }
              }
              if (_isSeekSwipe) {
                final durationMs = ref.read(playerProvider).duration.inMilliseconds;
                if (durationMs > 0) {
                  final deltaMs = (details.localFocalPoint.dx - _dragStartDx) * 300;
                  final seekStartMs = _seekStartProgress * durationMs;
                  final newMs = (seekStartMs + deltaMs).clamp(0.0, durationMs.toDouble());
                  ref.read(playerProvider.notifier).updateSeek(newMs / durationMs);
                }
              } else {
                ref.read(playerProvider.notifier).updateSwipe(details.focalPointDelta.dy, size.height);
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
                () {
                  if (mounted) _postPinchCooldown = false;
                },
              );
            } else if (_swipeActive) {
              _swipeActive = false;
              if (_swipeCommitted) {
                if (_isSeekSwipe) {
                  ref.read(playerProvider.notifier).endSeek(ref.read(playerProvider).seekValue);
                } else {
                  ref.read(playerProvider.notifier).endSwipe();
                }
              }
            }
          },
          child: widget.child,
        ),

        // Seek flash overlays
        if (_seekFlashLeft)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: size.width / 2,
            child: SeekFlash(animation: _seekFlashAnim, isForward: false),
          ),
        if (_seekFlashRight)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: size.width / 2,
            child: SeekFlash(animation: _seekFlashAnim, isForward: true),
          ),
      ],
    );
  }
}
