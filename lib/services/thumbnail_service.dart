import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Generates and caches video thumbnails to disk.
///
/// FIX #6: The _inFlight map previously never evicted completed futures,
/// leaking memory proportional to library size. Now futures are removed
/// from the map immediately after completion (success or failure).
class ThumbnailService {
  ThumbnailService._();
  static final ThumbnailService instance = ThumbnailService._();

  // In-memory dedup: prevents spawning two generations for the same path
  // while the first one is still in flight.
  final Map<String, Future<File?>> _inFlight = {};

  late final Future<Directory> _cacheDir = _initCacheDir();

  static Future<Directory> _initCacheDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'vid_thumbs'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File?> getThumbnail(String videoPath) {
    // If already generating, reuse the in-flight future (dedup).
    // FIX #6: putIfAbsent returns the existing future if present, so we only
    // schedule one generation. The future removes itself from _inFlight when done.
    return _inFlight.putIfAbsent(videoPath, () => _generate(videoPath));
  }

  Future<File?> _generate(String videoPath) async {
    try {
      final cacheFile = await _cacheFileFor(videoPath);

      if (await cacheFile.exists()) {
        // FIX #6: evict from map immediately after returning cached result
        _inFlight.remove(videoPath);
        return cacheFile;
      }

      final bytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        timeMs: 3000,
        maxWidth: 160,
        quality: 75,
      );

      _inFlight.remove(videoPath); // FIX #6: evict after generation completes

      if (bytes == null || bytes.isEmpty) return null;

      await cacheFile.writeAsBytes(bytes, flush: true);
      return cacheFile;
    } catch (_) {
      _inFlight.remove(videoPath); // FIX #6: evict on error too
      return null;
    }
  }

  Future<File> _cacheFileFor(String videoPath) async {
    final dir = await _cacheDir;
    // Use a sanitised filename as cache key (same approach as PositionService)
    final sanitised =
        videoPath.replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '_');
    return File(p.join(dir.path, '$sanitised.jpg'));
  }

  /// Clears all cached thumbnails from disk (e.g. for a settings "clear cache" button).
  Future<void> clearCache() async {
    try {
      final dir = await _cacheDir;
      if (await dir.exists()) {
        await for (final f in dir.list()) {
          if (f is File) await f.delete();
        }
      }
    } catch (_) {}
  }
}
