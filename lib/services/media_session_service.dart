import 'package:flutter/services.dart';

/// Manages Android media session (lock screen controls) via platform channel.
/// Uses MediaSessionCompat from Android's support library via a method channel.
/// Note: For full lock screen support, `audio_service` package can be added,
/// but this lightweight approach works for basic play/pause via system media session.
class MediaSessionService {
  static const _channel = MethodChannel('com.example.flutter_video_player/media_session');

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
