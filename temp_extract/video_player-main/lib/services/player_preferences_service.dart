import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-session player preferences that survive app restarts:
/// fit mode (FIT / CROP / FILL / AUTO), playback speed, and folder sort order.
///
/// SharedPreferences is resolved once and cached — repeated reads/writes
/// are synchronous map lookups after the first await.
class PlayerPreferencesService {
  PlayerPreferencesService._();
  static final PlayerPreferencesService instance = PlayerPreferencesService._();

  // Cached — only one platform channel call across the app lifetime.
  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const _fitModeKey   = 'player_fit_mode_v1';
  static const _speedKey     = 'player_speed_v1';
  static const _sortByKey    = 'folder_sort_by_v1';
  static const _themeModeKey = 'app_theme_mode_v1';

  // ── Fit mode ──────────────────────────────────────────────────────────────

  Future<int> loadFitModeIndex() async {
    try { return (await _p).getInt(_fitModeKey) ?? 0; } catch (_) { return 0; }
  }

  Future<void> saveFitModeIndex(int index) async {
    try { await (await _p).setInt(_fitModeKey, index); } catch (_) {}
  }

  // ── Playback speed ─────────────────────────────────────────────────────────

  Future<double> loadSpeed() async {
    try { return (await _p).getDouble(_speedKey) ?? 1.0; } catch (_) { return 1.0; }
  }

  Future<void> saveSpeed(double speed) async {
    try { await (await _p).setDouble(_speedKey, speed); } catch (_) {}
  }

  // ── Folder sort order ──────────────────────────────────────────────────────

  Future<int> loadSortByIndex() async {
    try { return (await _p).getInt(_sortByKey) ?? 0; } catch (_) { return 0; }
  }

  Future<void> saveSortByIndex(int index) async {
    try { await (await _p).setInt(_sortByKey, index); } catch (_) {}
  }

  // ── Theme mode ─────────────────────────────────────────────────────────────

  Future<int> loadThemeModeIndex() async {
    try { return (await _p).getInt(_themeModeKey) ?? 0; } catch (_) { return 0; }
  }

  Future<void> saveThemeModeIndex(int index) async {
    try { await (await _p).setInt(_themeModeKey, index); } catch (_) {}
  }
}
