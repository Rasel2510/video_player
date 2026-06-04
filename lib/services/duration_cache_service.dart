import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import '../models/video_file.dart';

/// Probes and caches video duration using media_kit's Player.
///
/// FIX #OPT-3: Added _probeInFlight dedup map so a folder with many uncached
///             videos doesn't spin up N simultaneous Player instances.
/// FIX #OPT-4: Switched cache key from videoPath.hashCode (collision-prone) to
///             the full sanitised path, consistent with PositionService.
///             Existing 'dur_<hashCode>' keys are silently ignored — they'll
///             be re-probed once and re-cached under the new key.
class DurationCacheService {
  DurationCacheService._();
  static final instance = DurationCacheService._();

  // Cached — only one platform channel call per app session.
  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const _prefix = 'dur_v2_'; // v2 = full-path key (not hashCode)

  // Compiled once — same sanitisation as PositionService.
  static final _sanitiseRe = RegExp(r'[^a-zA-Z0-9._\-]');

  static String _key(String videoPath) {
    final sanitised = videoPath.replaceAll(_sanitiseRe, '_');
    return '$_prefix$sanitised';
  }

  // ── Probe dedup ───────────────────────────────────────────────────────────
  // Prevents spinning up multiple Player instances for the same path when
  // _loadPositions() fires parallel getDuration() calls for uncached videos.
  final Map<String, Future<Duration?>> _probeInFlight = {};

  /// Returns cached duration, or probes the file if not cached yet.
  Future<Duration?> getDuration(String videoPath) async {
    final cached = (await _p).getInt(_key(videoPath));
    if (cached != null && cached > 0) return Duration(milliseconds: cached);
    return _probeDeduped(videoPath);
  }

  Future<Duration?> _probeDeduped(String videoPath) {
    return _probeInFlight.putIfAbsent(
      videoPath,
      () => _probe(videoPath).whenComplete(() => _probeInFlight.remove(videoPath)),
    );
  }

  Future<Duration?> _probe(String videoPath) async {
    if (!File(videoPath).existsSync()) return null;
    try {
      final player = Player();
      Duration? result;

      // Use stream listener instead of polling so we get the duration as soon
      // as media_kit reports it rather than waiting for the full poll interval.
      final completer = Completer<Duration?>();
      final sub = player.stream.duration.listen((d) {
        if (d > Duration.zero && !completer.isCompleted) completer.complete(d);
      });

      // 3-second timeout — same ceiling as the old polling approach.
      await player.open(Media(videoPath), play: false);
      result = await completer.future
          .timeout(const Duration(seconds: 3), onTimeout: () => null);

      await sub.cancel();
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
    await (await _p).setInt(_key(path), d.inMilliseconds);
  }

  Future<void> saveDuration(String videoPath, Duration duration) async {
    if (duration <= Duration.zero) return;
    await _cache(videoPath, duration);
  }

  Future<List<VideoFile>> enrichAll(List<VideoFile> files) async {
    final p = await _p;
    return files.map((vf) {
      if (vf.duration != null) return vf;
      final ms = p.getInt(_key(vf.path));
      if (ms != null && ms > 0) {
        return vf.copyWith(duration: Duration(milliseconds: ms));
      }
      return vf;
    }).toList();
  }
}
