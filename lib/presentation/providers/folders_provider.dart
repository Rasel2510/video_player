import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/video_file.dart';
import '../../models/video_folder.dart';
import '../../services/folder_scanner.dart';

// ── Storage root discovery ────────────────────────────────────────────────────

/// Returns all mounted storage roots on Android:
/// - /storage/emulated/0  (internal storage, always present)
/// - /storage/XXXX-XXXX   (SD cards, USB OTG, etc.)
/// Skips roots that don't exist or aren't readable.
List<String> _discoverStorageRoots() {
  final roots = <String>[];
  try {
    final storageDir = Directory('/storage');
    if (!storageDir.existsSync()) return ['/storage/emulated/0'];

    for (final entity in storageDir.listSync(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = entity.path.split('/').last;
      // 'self' is a symlink loop, skip it
      if (name == 'self') continue;

      if (name == 'emulated') {
        // /storage/emulated/0 is the real internal path
        final internal = Directory('${entity.path}/0');
        if (internal.existsSync()) roots.add(internal.path);
      } else {
        // SD card / USB OTG: names like "B4E5-120C"
        if (entity.existsSync()) roots.add(entity.path);
      }
    }
  } catch (_) {}

  if (roots.isEmpty) roots.add('/storage/emulated/0');
  return roots;
}

// ── Cache helpers ─────────────────────────────────────────────────────────────

const _cacheKey     = 'folder_scan_cache_v2';
const _cacheTimeKey = 'folder_scan_time_v2';
const _cacheTtl     = Duration(hours: 12);

// We store a lightweight "snapshot" of folder→videoCount to detect
// new folders/files without doing a full scan.
const _snapshotKey  = 'folder_scan_snapshot_v2';

Future<List<VideoFolder>?> _loadCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final ts  = prefs.getInt(_cacheTimeKey) ?? 0;
    final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(ts));
    if (age > _cacheTtl) return null;

    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;

    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => _folderFromMap(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return null;
  }
}

Future<void> _saveCache(List<VideoFolder> folders) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(_cacheKey, jsonEncode(folders.map(_folderToMap).toList()));
    // Save snapshot: Map<folderPath, videoCount>
    final snapshot = {for (final f in folders) f.path: f.videoCount};
    await prefs.setString(_snapshotKey, jsonEncode(snapshot));
  } catch (_) {}
}

/// Quick check: scan folder paths & counts WITHOUT reading file metadata.
/// Returns true if anything changed vs the cached snapshot.
Future<bool> _hasNewContent() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final rawSnapshot = prefs.getString(_snapshotKey);
    if (rawSnapshot == null) return true; // no snapshot → treat as changed

    final oldSnapshot = Map<String, int>.from(
        (jsonDecode(rawSnapshot) as Map).map((k, v) => MapEntry(k as String, v as int)));

    final roots = _discoverStorageRoots();
    for (final root in roots) {
      await _quickScan(Directory(root), oldSnapshot);
    }
    return false; // completed without throwing → no changes found
  } catch (e) {
    if (e is _ChangedSignal) return true;
    return false;
  }
}

/// Walks the tree quickly (no file stat), throws [_ChangedSignal] on change.
Future<void> _quickScan(
    Directory dir, Map<String, int> snapshot) async {
  try {
    int videoCount = 0;
    final subs = <Directory>[];

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && VideoFile.isVideoFile(entity.path)) {
        videoCount++;
      } else if (entity is Directory) {
        final name = entity.path.split('/').last;
        if (!name.startsWith('.')) subs.add(entity);
      }
    }

    if (videoCount > 0) {
      final cached = snapshot[dir.path];
      if (cached == null || cached != videoCount) throw _ChangedSignal();
    }

    for (final sub in subs) {
      await _quickScan(sub, snapshot);
    }
  } on _ChangedSignal {
    rethrow;
  } catch (_) {}
}

class _ChangedSignal implements Exception {}

Map<String, dynamic> _folderToMap(VideoFolder f) => {
      'path': f.path,
      'videos': f.videos.map((v) => {
            'path': v.path,
            'name': v.name,
            'size': v.size,
            'modified': v.modified.millisecondsSinceEpoch,
          }).toList(),
    };

VideoFolder _folderFromMap(Map<String, dynamic> m) => VideoFolder(
      path: m['path'] as String,
      videos: (m['videos'] as List<dynamic>)
          .map((v) => VideoFile(
                path: v['path'] as String,
                name: v['name'] as String,
                size: v['size'] as int,
                modified: DateTime.fromMillisecondsSinceEpoch(v['modified'] as int),
              ))
          .toList(),
    );

// ── State ─────────────────────────────────────────────────────────────────────

class FoldersState {
  final List<VideoFolder> folders;
  final bool isScanning;
  final int scanProgress;
  final bool fromCache;
  final List<String> storageRoots; // all mounted roots found

  const FoldersState({
    this.folders    = const [],
    this.isScanning = false,
    this.scanProgress = 0,
    this.fromCache  = false,
    this.storageRoots = const [],
  });

  FoldersState copyWith({
    List<VideoFolder>? folders,
    bool? isScanning,
    int?  scanProgress,
    bool? fromCache,
    List<String>? storageRoots,
  }) =>
      FoldersState(
        folders:      folders      ?? this.folders,
        isScanning:   isScanning   ?? this.isScanning,
        scanProgress: scanProgress ?? this.scanProgress,
        fromCache:    fromCache    ?? this.fromCache,
        storageRoots: storageRoots ?? this.storageRoots,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class FoldersNotifier extends Notifier<FoldersState> {
  @override
  FoldersState build() => const FoldersState();

  /// Called on first load and on app resume.
  /// - Loads cache instantly on first open.
  /// - On resume, does a lightweight check; rescans only if new content found.
  /// - [forceScan] skips cache entirely (RESCAN button).
  Future<void> load({bool forceScan = false}) async {
    // Already scanning → ignore
    if (state.isScanning) return;

    final roots = _discoverStorageRoots();

    if (forceScan) {
      await _fullScan(roots);
      return;
    }

    // First load: try cache
    if (state.folders.isEmpty) {
      final cached = await _loadCache();
      if (cached != null && cached.isNotEmpty) {
        state = state.copyWith(
          folders: cached,
          fromCache: true,
          storageRoots: roots,
        );
        // Then silently check for new content in background
        _backgroundCheck(roots);
        return;
      }
      // No cache → full scan
      await _fullScan(roots);
      return;
    }

    // Already have data (e.g. app resumed) → quick check only
    _backgroundCheck(roots);
  }

  /// Lightweight background check — if new content found, triggers full rescan.
  Future<void> _backgroundCheck(List<String> roots) async {
    final changed = await _hasNewContent();
    if (changed) {
      await _fullScan(roots);
    }
  }

  Future<void> _fullScan(List<String> roots) async {
    state = state.copyWith(
      isScanning: true,
      folders: state.folders, // keep old list visible while scanning
      scanProgress: 0,
      fromCache: false,
      storageRoots: roots,
    );

    // Scan all roots and merge results
    final Map<String, List<VideoFile>> folderMap = {};
    int progress = 0;

    for (final root in roots) {
      final folders = await FolderScanner.scanFolders(
        root,
        onProgress: (n) {
          progress += 1;
          state = state.copyWith(scanProgress: progress);
        },
      );
      for (final f in folders) {
        folderMap.putIfAbsent(f.path, () => []).addAll(f.videos);
      }
    }

    final merged = folderMap.entries.map((e) {
      final videos = e.value
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return VideoFolder(path: e.key, videos: videos);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    state = state.copyWith(
      folders: merged,
      isScanning: false,
      fromCache: false,
    );

    await _saveCache(merged);
  }

  void reset() => state = const FoldersState();
}

final foldersProvider = NotifierProvider<FoldersNotifier, FoldersState>(
  FoldersNotifier.new,
);
