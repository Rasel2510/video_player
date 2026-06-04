import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Generates and caches video thumbnails to disk.
///
/// FIX #6:  The _inFlight map now evicts completed futures immediately.
/// FIX #OPT: Added a concurrency semaphore (max 4 simultaneous generations)
///           so fast-scrolling a large folder doesn't spawn unbounded
///           MediaMetadataRetriever calls and exhaust memory / cause jank.
class ThumbnailService {
  ThumbnailService._();
  static final ThumbnailService instance = ThumbnailService._();

  // ── Concurrency semaphore ─────────────────────────────────────────────────
  // At most _kMaxConcurrent thumbnail generations run at the same time.
  // Additional callers queue in _waiters and are unblocked in FIFO order.
  static const int _kMaxConcurrent = 4;
  int _activeCount = 0;
  final List<Completer<void>> _waiters = [];

  Future<void> _acquire() async {
    if (_activeCount < _kMaxConcurrent) {
      _activeCount++;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      // Wake the next waiter — it already "owns" the slot (activeCount stays same).
      _waiters.removeAt(0).complete();
    } else {
      _activeCount--;
    }
  }

  // ── In-flight dedup ───────────────────────────────────────────────────────
  // Prevents spawning two generations for the same path while the first is
  // still in flight. Entries are removed immediately after completion.
  final Map<String, Future<File?>> _inFlight = {};

  late final Future<Directory> _cacheDir = _initCacheDir();

  // Compiled once — reused for every cache filename sanitisation.
  static final _sanitiseRe = RegExp(r'[^a-zA-Z0-9._\-]');

  static Future<Directory> _initCacheDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'vid_thumbs'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File?> getThumbnail(String videoPath) {
    return _inFlight.putIfAbsent(videoPath, () => _generate(videoPath));
  }

  Future<File?> _generate(String videoPath) async {
    await _acquire();
    try {
      final cacheFile = await _cacheFileFor(videoPath);

      if (await cacheFile.exists()) {
        return cacheFile;
      }

      final bytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        timeMs: 3000,
        maxWidth: 160,
        quality: 75,
      );

      if (bytes == null || bytes.isEmpty) return null;

      await cacheFile.writeAsBytes(bytes, flush: true);
      return cacheFile;
    } catch (_) {
      return null;
    } finally {
      // Always release the semaphore slot and evict from the in-flight map,
      // whether generation succeeded, returned null, or threw.
      _release();
      _inFlight.remove(videoPath);
    }
  }

  Future<File> _cacheFileFor(String videoPath) async {
    final dir = await _cacheDir;
    final sanitised = videoPath.replaceAll(_sanitiseRe, '_');
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
