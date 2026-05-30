import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import '../models/video_file.dart';

/// Probes and caches video duration using media_kit's Player.
/// Cache key: 'dur_<path.hashCode>'
class DurationCacheService {
  DurationCacheService._();
  static final instance = DurationCacheService._();

  static const _prefix = 'dur_';

  /// Returns cached duration, or probes the file if not cached yet.
  Future<Duration?> getDuration(String videoPath) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${videoPath.hashCode}';
    final cached = prefs.getInt(key);
    if (cached != null && cached > 0) {
      return Duration(milliseconds: cached);
    }
    // Probe via media_kit
    return await _probe(videoPath);
  }

  Future<Duration?> _probe(String videoPath) async {
    if (!File(videoPath).existsSync()) return null;
    try {
      final player = Player();
      await player.open(Media(videoPath), play: false);
      // Wait up to 3 s for duration to be available
      Duration? result;
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        final d = player.state.duration;
        if (d > Duration.zero) {
          result = d;
          break;
        }
      }
      await player.dispose();
      if (result != null && result > Duration.zero) {
        await _cache(videoPath, result);
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cache(String path, Duration d) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix${path.hashCode}', d.inMilliseconds);
  }

  /// Called from PlayerNotifier when duration becomes known — saves it
  /// immediately so list views show the correct value next time.
  Future<void> saveDuration(String videoPath, Duration duration) async {
    if (duration <= Duration.zero) return;
    await _cache(videoPath, duration);
  }

  /// Load duration for a list of VideoFiles (enriches them with cached data).
  Future<List<VideoFile>> enrichAll(List<VideoFile> files) async {
    final prefs = await SharedPreferences.getInstance();
    return files.map((vf) {
      if (vf.duration != null) return vf;
      final ms = prefs.getInt('$_prefix${vf.path.hashCode}');
      if (ms != null && ms > 0) {
        return vf.copyWith(duration: Duration(milliseconds: ms));
      }
      return vf;
    }).toList();
  }
}
