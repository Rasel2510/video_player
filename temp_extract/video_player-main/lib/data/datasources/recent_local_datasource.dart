import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/video_entity.dart';

class RecentLocalDataSource {
  // Cached SharedPreferences — only one platform channel call per session.
  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const _key = 'recent_videos_v2';
  static const _maxItems = 20;

  Future<List<VideoEntity>> getRecents() async {
    final prefs = await _p;
    final raw = prefs.getStringList(_key) ?? [];
    final result = <VideoEntity>[];
    for (final s in raw) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        final entity = _fromMap(map);
        if (File(entity.path).existsSync()) result.add(entity);
      } catch (_) {}
    }
    return result;
  }

  Future<void> addRecent(VideoEntity video) async {
    final prefs = await _p;
    final raw = prefs.getStringList(_key) ?? [];

    raw.removeWhere((s) {
      try {
        return (_fromMap(jsonDecode(s) as Map<String, dynamic>)).path ==
            video.path;
      } catch (_) {
        return false;
      }
    });

    raw.insert(0, jsonEncode(_toMap(video)));
    await prefs.setStringList(_key, raw.take(_maxItems).toList());
  }

  Future<void> removeRecent(String path) async {
    final prefs = await _p;
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((s) {
      try {
        return (_fromMap(jsonDecode(s) as Map<String, dynamic>)).path == path;
      } catch (_) {
        return true;
      }
    });
    await prefs.setStringList(_key, raw);
  }

  Future<void> clearAll() async {
    final prefs = await _p;
    await prefs.remove(_key);
  }

  Map<String, dynamic> _toMap(VideoEntity v) => {
        'path': v.path,
        'name': v.name,
        'sizeBytes': v.sizeBytes,
        'lastModified': v.lastModified.millisecondsSinceEpoch,
      };

  VideoEntity _fromMap(Map<String, dynamic> m) => VideoEntity(
        path: m['path'] as String,
        name: m['name'] as String,
        sizeBytes: m['sizeBytes'] as int,
        lastModified:
            DateTime.fromMillisecondsSinceEpoch(m['lastModified'] as int),
      );
}
