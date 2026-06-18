import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../models/video_file.dart';

/// Dart side of the native MediaStore bridge (Android only).
///
/// Replaces the slow recursive filesystem walk with a single fast MediaStore
/// query, and exposes a change callback fired by the native ContentObserver so
/// newly downloaded / deleted videos appear live without a manual rescan.
class MediaStoreService {
  static const _channel = MethodChannel(AppConstants.mediaStoreChannel);

  /// Queries the entire video index. Returns an empty list on any platform
  /// without the native bridge (iOS, desktop) or on error.
  static Future<List<VideoFile>> queryVideos() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('queryVideos');
      if (raw == null) return [];
      return raw.map((e) {
        final m = (e as Map).cast<dynamic, dynamic>();
        final durMs = (m['duration'] as num?)?.toInt() ?? 0;
        return VideoFile(
          path: m['path'] as String,
          name: m['name'] as String,
          size: (m['size'] as num).toInt(),
          modified:
              DateTime.fromMillisecondsSinceEpoch((m['modified'] as num).toInt()),
          duration: durMs > 0 ? Duration(milliseconds: durMs) : null,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Registers [onChanged] for native MediaStore change notifications. Only one
  /// handler is kept (the library is the single consumer).
  static void setChangeHandler(void Function() onChanged) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onChanged') onChanged();
    });
  }

  static Future<void> startWatching() async {
    try {
      await _channel.invokeMethod('startWatching');
    } catch (_) {}
  }

  static Future<void> stopWatching() async {
    try {
      await _channel.invokeMethod('stopWatching');
    } catch (_) {}
  }
}
