import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-session player preferences that survive app restarts:
/// fit mode (FIT / CROP / FILL / AUTO), playback speed, and folder sort order.
///
/// Kept deliberately thin — single responsibility, no business logic.
class PlayerPreferencesService {
  PlayerPreferencesService._();
  static final PlayerPreferencesService instance = PlayerPreferencesService._();

  static const _fitModeKey  = 'player_fit_mode_v1';
  static const _speedKey    = 'player_speed_v1';
  static const _sortByKey   = 'folder_sort_by_v1';
  static const _themeModeKey = 'app_theme_mode_v1';

  // ── Fit mode ──────────────────────────────────────────────────────────────

  Future<int> loadFitModeIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_fitModeKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> saveFitModeIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_fitModeKey, index);
    } catch (_) {}
  }

  // ── Playback speed ─────────────────────────────────────────────────────────

  Future<double> loadSpeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_speedKey) ?? 1.0;
    } catch (_) {
      return 1.0;
    }
  }

  Future<void> saveSpeed(double speed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_speedKey, speed);
    } catch (_) {}
  }

  // ── Folder sort order ──────────────────────────────────────────────────────

  /// Returns the saved sort-option index, or 0 (name) as default.
  Future<int> loadSortByIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_sortByKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> saveSortByIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_sortByKey, index);
    } catch (_) {}
  }

  // ── Theme mode ─────────────────────────────────────────────────────────────

  Future<int> loadThemeModeIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_themeModeKey) ?? 0; // 0 = system, 1 = light, 2 = dark
    } catch (_) {
      return 0;
    }
  }

  Future<void> saveThemeModeIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeModeKey, index);
    } catch (_) {}
  }
}
