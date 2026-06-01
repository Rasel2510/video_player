import 'package:shared_preferences/shared_preferences.dart';

/// Persists and restores the user's preferred screen brightness for the video player.
class BrightnessService {
  BrightnessService._();
  static final instance = BrightnessService._();

  static const _key = 'player_brightness';

  /// Loads the persisted brightness. Returns null if not set.
  Future<double?> getBrightness() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_key) ? prefs.getDouble(_key) : null;
    } catch (_) {
      return null;
    }
  }

  /// Saves the current brightness to SharedPreferences.
  Future<void> saveBrightness(double brightness) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_key, brightness);
    } catch (_) {}
  }
}
