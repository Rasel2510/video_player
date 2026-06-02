import 'package:flutter/services.dart';
import '../core/constants.dart';

/// Manages Android media session (lock screen controls) via platform channel.
class MediaSessionService {
  // FIX #14: use the shared constant instead of a duplicate string literal
  static const _channel = MethodChannel(AppConstants.mediaSessionChannel);

  static Future<void> setMetadata({
    required String title,
    required Duration duration,
  }) async {
    try {
      await _channel.invokeMethod('setMetadata', {
        'title': title,
        'duration': duration.inMilliseconds,
      });
    } catch (_) {}
  }

  static Future<void> setPlaybackState({
    required bool isPlaying,
    required Duration position,
    required double speed,
  }) async {
    try {
      await _channel.invokeMethod('setPlaybackState', {
        'isPlaying': isPlaying,
        'position': position.inMilliseconds,
        'speed': speed,
      });
    } catch (_) {}
  }

  static Future<void> release() async {
    try {
      await _channel.invokeMethod('release');
    } catch (_) {}
  }
}
