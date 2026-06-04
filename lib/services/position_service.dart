import 'package:shared_preferences/shared_preferences.dart';
import 'duration_cache_service.dart';

/// Saves and restores the last playback position for each video file.
///
/// FIX #OPT-9 / latent bug: _sanitiseRe was referenced but never defined in
/// this file.  Added the definition here.  The key strategy (full sanitised
/// path) is intentional and consistent with DurationCacheService — it avoids
/// hash collisions at the cost of slightly longer key strings, which is an
/// acceptable trade-off given typical Android path lengths (~60–90 chars after
/// sanitisation) and that SharedPreferences stores keys as XML on Android with
/// no documented length constraint.
class PositionService {
  PositionService._();
  static final PositionService instance = PositionService._();

  // Cached — only one platform channel call per app session.
  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const _prefix    = 'pos_v2_';
  static const _minSaveMs = 5000;
  static const _nearEndMs = 5000;

  // Compiled once — replaces any character that is not alphanumeric, dot,
  // underscore, or hyphen with '_'.  Same pattern as ThumbnailService and
  // DurationCacheService so all three services produce identical path keys.
  static final _sanitiseRe = RegExp(r'[^a-zA-Z0-9._\-]');

  static String _key(String videoPath) {
    final sanitised = videoPath.replaceAll(_sanitiseRe, '_');
    return '$_prefix$sanitised';
  }

  Future<void> save(String videoPath, Duration position, Duration duration) async {
    final ms      = position.inMilliseconds;
    final totalMs = duration.inMilliseconds;
    if (totalMs <= 0 || ms < _minSaveMs) return;
    final p = await _p;
    if (totalMs - ms < _nearEndMs) {
      await p.remove(_key(videoPath));
      return;
    }
    // Persist position and duration cache in parallel.
    await Future.wait([
      p.setInt(_key(videoPath), ms),
      DurationCacheService.instance
          .saveDuration(videoPath, Duration(milliseconds: totalMs)),
    ]);
  }

  Future<Duration?> load(String videoPath) async {
    final ms = (await _p).getInt(_key(videoPath));
    if (ms == null || ms < _minSaveMs) return null;
    return Duration(milliseconds: ms);
  }

  Future<void> clear(String videoPath) async {
    await (await _p).remove(_key(videoPath));
  }

  Future<bool> hasSaved(String videoPath) async {
    final ms = (await _p).getInt(_key(videoPath));
    return ms != null && ms >= _minSaveMs;
  }
}
