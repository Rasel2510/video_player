import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../services/thumbnail_service.dart';
import '../../core/utils/duration_formatter.dart';

// ── Shared shimmer ────────────────────────────────────────────────────────────
//
// FIX #OPT-8: Previously every loading thumbnail ran its own AnimationController.
// For a folder with 50 uncached videos that meant 50 simultaneous controllers
// all ticking on the UI thread.
//
// The fix uses an InheritedWidget + a single top-level controller that all
// _Shimmer instances listen to.  The controller lives in a StatefulWidget
// (_ShimmerScope) placed once in the widget tree (inside app.dart or any
// common ancestor); all loading thumbnails share the same animation value.

/// Place this once above any screen that shows [VideoThumbnailWidget].
/// It vends a single [Animation<double>] to all shimmer consumers below it.
class ShimmerScope extends StatefulWidget {
  final Widget child;
  const ShimmerScope({super.key, required this.child});

  /// Returns the shimmer opacity from the nearest [ShimmerScope].
  /// Falls back to a fixed 0.08 if no scope is found (e.g. in tests).
  static Animation<double> of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ShimmerScopeData>();
    return scope?.animation ?? const AlwaysStoppedAnimation(0.08);
  }

  @override
  State<ShimmerScope> createState() => _ShimmerScopeState();
}

class _ShimmerScopeState extends State<ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  late final Animation<double> _anim =
      Tween(begin: 0.04, end: 0.12).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScopeData(animation: _anim, child: widget.child);
  }
}

class _ShimmerScopeData extends InheritedWidget {
  final Animation<double> animation;
  const _ShimmerScopeData({
    required this.animation,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ShimmerScopeData old) => false; // animation is stable
}

// ── Thumbnail widget ──────────────────────────────────────────────────────────

/// Async thumbnail with shimmer placeholder and graceful fallback.
class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;
  final double width;
  final double height;
  final Duration? duration;

  const VideoThumbnailWidget({
    super.key,
    required this.videoPath,
    this.width = 88,
    this.height = 58,
    this.duration,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  File? _thumb;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VideoThumbnailWidget old) {
    super.didUpdateWidget(old);
    if (old.videoPath != widget.videoPath) {
      setState(() {
        _thumb = null;
        _failed = false;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final file =
        await ThumbnailService.instance.getThumbnail(widget.videoPath);
    if (!mounted) return;
    setState(() {
      _thumb = file;
      _failed = file == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: _buildInner(context),
    );
  }

  Widget _buildInner(BuildContext context) {
    if (_thumb != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            _thumb!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(context),
          ),
          const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x80000000),
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
          if (widget.duration != null && widget.duration!.inSeconds > 0)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: const BoxDecoration(
                  color: Color(0xB3000000),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                child: Text(
                  DurationFormatter.format(widget.duration!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
        ],
      );
    }
    if (_failed) return _placeholder(context);
    // Show shimmer using the shared animation from ShimmerScope.
    return _Shimmer(animation: ShimmerScope.of(context));
  }

  Widget _placeholder(BuildContext context) => Container(
        color: context.colors.elevated,
        child:
            Icon(Icons.movie_outlined, color: context.colors.textMuted, size: 22),
      );
}

// ── Shimmer ───────────────────────────────────────────────────────────────────

/// A simple opacity-shimmer that reads its animation from [ShimmerScope].
/// Stateless because it no longer owns an AnimationController.
class _Shimmer extends AnimatedWidget {
  const _Shimmer({required Animation<double> animation})
      : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final value = (listenable as Animation<double>).value;
    return Container(color: Color.fromRGBO(255, 255, 255, value));
  }
}
