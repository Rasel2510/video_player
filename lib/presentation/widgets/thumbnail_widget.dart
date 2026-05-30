import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/thumbnail_service.dart';

/// Async thumbnail widget with shimmer placeholder and graceful fallback.
/// Works for any video path. Caches to disk via [ThumbnailService].
class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;
  final double width;
  final double height;

  const VideoThumbnailWidget({
    super.key,
    required this.videoPath,
    this.width = 80,
    this.height = 56,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: _buildInner(),
      ),
    );
  }

  Widget _buildInner() {
    // Thumbnail loaded successfully
    if (_thumb != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            _thumb!,
            fit: BoxFit.cover,
            // If file was deleted externally, fall back gracefully
            errorBuilder: (_, __, ___) => _placeholder(),
          ),
          // Subtle dark play icon overlay
          Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow,
                  color: Colors.white, size: 15),
            ),
          ),
        ],
      );
    }

    // Failed to generate (unsupported format, etc.)
    if (_failed) return _placeholder();

    // Still loading → shimmer
    return _Shimmer();
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF1A1A1A),
        child: const Icon(Icons.movie_outlined,
            color: Color(0xFF3A3A3A), size: 22),
      );
}

/// Simple shimmer animation shown while thumbnail generates.
class _Shimmer extends StatefulWidget {
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.06, end: 0.18).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        color: Color.fromRGBO(255, 255, 255, _anim.value),
      ),
    );
  }
}
