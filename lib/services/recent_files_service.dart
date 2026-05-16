import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_file.dart';

class RecentFilesService {
  static const _key = 'recent_videos';
  static const _maxItems = 20;

  static Future<List<VideoFile>> getRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final files = <VideoFile>[];
    for (final s in raw) {
      try {
        final vf = VideoFile.fromJson(jsonDecode(s));
        // Only include if file still exists
        if (File(vf.path).existsSync()) {
          files.add(vf);
        }
      } catch (_) {}
    }
    return files;
  }

  static Future<void> addRecent(VideoFile vf) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];

    // Remove existing entry for same path
    raw.removeWhere((s) {
      try {
        return VideoFile.fromJson(jsonDecode(s)).path == vf.path;
      } catch (_) {
        return false;
      }
    });

    // Insert at front
    raw.insert(0, jsonEncode(vf.toJson()));

    // Trim to max
    final trimmed = raw.take(_maxItems).toList();
    await prefs.setStringList(_key, trimmed);
  }

  static Future<void> removeRecent(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((s) {
      try {
        return VideoFile.fromJson(jsonDecode(s)).path == path;
      } catch (_) {
        return true;
      }
    });
    await prefs.setStringList(_key, raw);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
