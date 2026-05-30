import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Generates and caches video thumbnails to disk.
///
/// - First call generates the thumbnail in the background and saves it
///   to the app temp directory.
/// - Subsequent calls return the cached file immediately — no regeneration.
/// - Cache key = sanitised video path, so it survives hot restarts.
class ThumbnailService {
  ThumbnailService._();
  static final ThumbnailService instance = ThumbnailService._();

  // In-memory dedup: prevents spawning two generations for the same path
  // if a widget rebuilds before the first one finishes.
  final Map<String, Future<File?>> _inFlight = {};

  late final Future<Directory> _cacheDir = _initCacheDir();

  static Future<Directory> _initCacheDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'vid_thumbs'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Returns a thumbnail [File] for [videoPath].
  /// Returns null on failure (unsupported codec, corrupt file, etc.).
  Future<File?> getThumbnail(String videoPath) {
    return _inFlight.putIfAbsent(videoPath, () => _generate(videoPath));
  }

  Future<File?> _generate(String videoPath) async {
    try {
      final cacheFile = await _cacheFileFor(videoPath);

      // Already on disk → return immediately
      if (await cacheFile.exists()) {
        _inFlight.remove(videoPath);
        return cacheFile;
      }

      // Generate at 3 s in (skips black opening frames for most videos).
      // video_thumbnail falls back to frame 0 if the video is shorter.
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        timeMs: 3000,
        maxWidth: 160, // 2× the 80 px display size for sharp screens
        quality: 75,
      );

      if (bytes == null || bytes.isEmpty) {
        _inFlight.remove(videoPath);
        return null;
      }

      await cacheFile.writeAsBytes(bytes, flush: true);
      _inFlight.remove(videoPath);
      return cacheFile;
    } catch (_) {
      _inFlight.remove(videoPath);
      return null;
    }
  }

  Future<File> _cacheFileFor(String videoPath) async {
    final dir = await _cacheDir;
    // Simple integer hash — good enough for a filename key
    final hash = videoPath.hashCode.toRadixString(16);
    // Include the basename so files are human-readable in the cache dir
    final base = p.basenameWithoutExtension(videoPath)
        .replaceAll(RegExp(r'[^\w]'), '_')
        .substring(0, 20.clamp(0, p.basenameWithoutExtension(videoPath).length));
    return File(p.join(dir.path, '${base}_$hash.jpg'));
  }

  /// Wipes all cached thumbnails (call if storage is low).
  Future<void> clearCache() async {
    try {
      final dir = await _cacheDir;
      if (await dir.exists()) {
        await for (final f in dir.list()) {
          try { await f.delete(); } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
