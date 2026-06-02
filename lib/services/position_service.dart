import 'package:shared_preferences/shared_preferences.dart';
import 'duration_cache_service.dart';

/// Saves and restores the last playback position for each video file.
///
/// FIX #1: Was using videoPath.hashCode as key — Dart's 32-bit hashCode has
/// collisions on large libraries. Now uses a sanitised path string as key,
/// which is unique by definition and survives across app restarts.
class PositionService {
  PositionService._();
  static final PositionService instance = PositionService._();

  static const _prefix = 'pos_v2_'; // new prefix so old hash-keyed data is ignored
  static const _minSaveMs  = 5000;  // ignore accidental opens < 5 s
  static const _nearEndMs  = 5000;  // clear position when within last 5 s (treat as finished)

  /// Sanitise a path into a safe SharedPreferences key.
  /// Replaces characters that can cause issues in some implementations.
  static String _key(String videoPath) {
    // Replace any character that isn't alphanumeric, dot, dash, or underscore
    final sanitised = videoPath.replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '_');
    return '$_prefix$sanitised';
  }

  Future<void> save(String videoPath, Duration position, Duration duration) async {
    final ms      = position.inMilliseconds;
    final totalMs = duration.inMilliseconds;
    if (totalMs <= 0 || ms < _minSaveMs) return;

    final prefs = await SharedPreferences.getInstance();

    // Clear if near the end — next open should start fresh
    if (totalMs - ms < _nearEndMs) {
      await prefs.remove(_key(videoPath));
      return;
    }
    await prefs.setInt(_key(videoPath), ms);

    if (totalMs > 0) {
      await DurationCacheService.instance
          .saveDuration(videoPath, Duration(milliseconds: totalMs));
    }
  }

  Future<Duration?> load(String videoPath) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_key(videoPath));
    if (ms == null || ms < _minSaveMs) return null;
    return Duration(milliseconds: ms);
  }

  Future<void> clear(String videoPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(videoPath));
  }

  Future<bool> hasSaved(String videoPath) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_key(videoPath));
    return ms != null && ms >= _minSaveMs;
  }
}
