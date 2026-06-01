import 'package:shared_preferences/shared_preferences.dart';

/// Persists and restores the user's preferred video player volume.
class VolumeService {
  VolumeService._();
  static final instance = VolumeService._();

  static const _key = 'player_volume';
  static const double defaultVolume = 100.0;

  /// Loads the persisted volume, defaulting to 100.0 if not set.
  Future<double> getVolume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_key) ?? defaultVolume;
    } catch (_) {
      return defaultVolume;
    }
  }

  /// Saves the current volume to SharedPreferences.
  Future<void> saveVolume(double volume) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_key, volume);
    } catch (_) {}
  }
}
