import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../services/thumbnail_service.dart';
import '../../../core/utils/duration_formatter.dart';

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
part 'widgets/shimmer_scope.dart';

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

  // Const white container — reused across every frame; only the Opacity
  // wrapper is rebuilt, eliminating the Color.fromRGBO allocation per tick.
  static const _kWhiteBox = ColoredBox(color: Colors.white);

  @override
  Widget build(BuildContext context) {
    final value = (listenable as Animation<double>).value;
    return Opacity(opacity: value, child: _kWhiteBox);
  }
}

