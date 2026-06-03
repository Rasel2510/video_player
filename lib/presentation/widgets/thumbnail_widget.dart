import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/thumbnail_service.dart';

/// Async thumbnail with shimmer placeholder and graceful fallback.
class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;
  final double width;
  final double height;

  const VideoThumbnailWidget({
    super.key,
    required this.videoPath,
    this.width = 88,
    this.height = 58,
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
      setState(() { _thumb = null; _failed = false; });
      _load();
    }
  }

  Future<void> _load() async {
    final file = await ThumbnailService.instance.getThumbnail(widget.videoPath);
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
      child: _buildInner(),
    );
  }

  Widget _buildInner() {
    if (_thumb != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            _thumb!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          ),
          Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      );
    }
    if (_failed) return _placeholder();
    return const _Shimmer();
  }

  Widget _placeholder() => Container(
        color: context.colors.elevated,
        child: Icon(Icons.movie_outlined,
            color: context.colors.textMuted, size: 22),
      );
}

class _Shimmer extends StatefulWidget {
  const _Shimmer();

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
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
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          color: Color.fromRGBO(255, 255, 255, _anim.value),
        ),
      );
}