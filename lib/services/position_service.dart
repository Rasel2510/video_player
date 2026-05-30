import 'package:shared_preferences/shared_preferences.dart';
import 'duration_cache_service.dart';

/// Saves and restores the last playback position for each video file.
/// Key = video path, value = position in milliseconds.
class PositionService {
  PositionService._();
  static final PositionService instance = PositionService._();

  static const _prefix = 'pos_';
  // Don't save position if less than 5 s played (accidental opens)
  static const _minSaveMs = 5000;
  // Clear saved position when within last 5 s of video (treat as finished)
  static const _nearEndMs = 5000;

  Future<void> save(String videoPath, Duration position, Duration duration) async {
    final ms = position.inMilliseconds;
    final totalMs = duration.inMilliseconds;
    if (totalMs <= 0 || ms < _minSaveMs) return;

    final prefs = await SharedPreferences.getInstance();

    // Clear if near the end — next open should start fresh
    if (totalMs > 0 && totalMs - ms < _nearEndMs) {
      await prefs.remove('$_prefix${videoPath.hashCode}');
      return;
    }
    await prefs.setInt('$_prefix${videoPath.hashCode}', ms);
    // Also cache the duration so list views can show progress bars
    if (totalMs > 0) {
      await DurationCacheService.instance
          .saveDuration(videoPath, Duration(milliseconds: totalMs));
    }
  }

  /// Returns null if no saved position exists.
  Future<Duration?> load(String videoPath) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('$_prefix${videoPath.hashCode}');
    if (ms == null || ms < _minSaveMs) return null;
    return Duration(milliseconds: ms);
  }

  Future<void> clear(String videoPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix${videoPath.hashCode}');
  }

  /// Check if a saved position exists without loading it (fast, for UI badge).
  Future<bool> hasSaved(String videoPath) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('$_prefix${videoPath.hashCode}');
    return ms != null && ms >= _minSaveMs;
  }
}
