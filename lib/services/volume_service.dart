import 'package:flutter_volume_controller/flutter_volume_controller.dart';

/// Controls and reads the device system volume (media stream).
/// Volume is in 0.0–1.0 range.
class VolumeService {
  VolumeService._();
  static final instance = VolumeService._();

  /// Gets the current device system volume (0.0 – 1.0).
  Future<double> getDeviceVolume() async {
    try {
      final vol = await FlutterVolumeController.getVolume();
      return (vol ?? 1.0).clamp(0.0, 1.0);
    } catch (_) {
      return 1.0;
    }
  }

  /// Sets the device system volume (0.0 – 1.0).
  Future<void> setDeviceVolume(double volume) async {
    try {
      await FlutterVolumeController.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  /// Listens to device volume changes, calling [onChanged] with 0.0–1.0 value.
  void addListener(void Function(double) onChanged) {
    FlutterVolumeController.addListener((vol) {
      onChanged(vol.clamp(0.0, 1.0));
    });
  }

  void removeListener() {
    FlutterVolumeController.removeListener();
  }
}
