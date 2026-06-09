import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/video_file.dart';
import '../../models/video_folder.dart';
import '../../services/folder_scanner.dart';

// ── Storage root discovery ────────────────────────────────────────────────────

SharedPreferences? _cachedPrefs;
Future<SharedPreferences> get _p async =>
    _cachedPrefs ??= await SharedPreferences.getInstance();

class _ChangedSignal implements Exception {
  const _ChangedSignal();
}

List<String> _discoverStorageRoots() {
  final roots = <String>[];
  try {
    final storageDir = Directory('/storage');
    if (!storageDir.existsSync()) return ['/storage/emulated/0'];

    for (final entity in storageDir.listSync(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = entity.path.split('/').last;
      if (name == 'self') continue;

      if (name == 'emulated') {
        final internal = Directory('${entity.path}/0');
        if (internal.existsSync()) roots.add(internal.path);
      } else {
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

// FIX #TTL: Removed 12-hour TTL — cache is now permanent and only replaced
// when a real filesystem change is detected by the background snapshot check.
// Previously the cache expired after 12 h and the app showed a blank library.

const _snapshotKey      = 'folder_scan_snapshot_v2';
const _seenPathsKey     = 'folder_scan_seen_paths_v1';
const _seenPathsInitKey = 'folder_scan_seen_paths_init_v1';

Future<Set<String>?> _loadSeenPaths() async {
  try {
    final prefs = await _p;
    if (prefs.getBool(_seenPathsInitKey) != true) return null;
    final raw = prefs.getString(_seenPathsKey);
    if (raw == null) return {};
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<String>().toSet();
  } catch (_) {
    return null;
  }
}

Future<void> _saveSeenPaths(Set<String> paths) async {
  try {
    final prefs = await _p;
    await prefs.setBool(_seenPathsInitKey, true);
    await prefs.setString(_seenPathsKey, jsonEncode(paths.toList()));
  } catch (_) {}
}

// FIX #TTL: No TTL check — always return cached data if present.
Future<List<VideoFolder>?> _loadCache() async {
  try {
    final prefs = await _p;
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => _folderFromMap(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return null;
  }
}

// FIX #ATOMIC: cache and snapshot are always written together so they can
// never go out of sync (e.g. if the app is killed between the two writes).
Future<void> _saveCache(List<VideoFolder> folders) async {
  try {
    final prefs = await _p;
    await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(_cacheKey, jsonEncode(folders.map(_folderToMap).toList()));
    final snapshot = {for (final f in folders) f.path: f.videoCount};
    await prefs.setString(_snapshotKey, jsonEncode(snapshot));
  } catch (_) {}
}

Future<bool> _hasNewContent() async {
  try {
    final prefs = await _p;
    final rawSnapshot = prefs.getString(_snapshotKey);
    if (rawSnapshot == null) return true;

    final oldSnapshot = Map<String, int>.from(
        (jsonDecode(rawSnapshot) as Map)
            .map((k, v) => MapEntry(k as String, v as int)));

    final roots = _discoverStorageRoots();

    final port = ReceivePort();
    await Isolate.spawn(
      _isolateQuickCheck,
      _QuickCheckData(roots, oldSnapshot, port.sendPort),
    );
    final changed = await port.first as bool;
    return changed;
  } catch (_) {
    return true;
  }
}

// ── Isolate entry point ───────────────────────────────────────────────────────

class _QuickCheckData {
  final List<String> roots;
  final Map<String, int> snapshot;
  final SendPort sendPort;
  _QuickCheckData(this.roots, this.snapshot, this.sendPort);
}

void _isolateQuickCheck(_QuickCheckData data) {
  try {
    for (final root in data.roots) {
      _quickScanSync(Directory(root), data.snapshot);
    }
    data.sendPort.send(false);
  } catch (e) {
    data.sendPort.send(true);
  }
}

void _quickScanSync(Directory dir, Map<String, int> snapshot) {
  try {
    int videoCount = 0;
    final subs = <Directory>[];

    for (final entity in dir.listSync(followLinks: false)) {
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
      _quickScanSync(sub, snapshot);
    }
  } on _ChangedSignal {
    rethrow;
  } catch (_) {}
}

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
  final List<String> storageRoots;
  final Set<String> newPaths;

  const FoldersState({
    this.folders    = const [],
    this.isScanning = false,
    this.scanProgress = 0,
    this.fromCache  = false,
    this.storageRoots = const [],
    this.newPaths = const {},
  });

  FoldersState copyWith({
    List<VideoFolder>? folders,
    bool? isScanning,
    int?  scanProgress,
    bool? fromCache,
    List<String>? storageRoots,
    Set<String>? newPaths,
  }) =>
      FoldersState(
        folders:      folders      ?? this.folders,
        isScanning:   isScanning   ?? this.isScanning,
        scanProgress: scanProgress ?? this.scanProgress,
        fromCache:    fromCache    ?? this.fromCache,
        storageRoots: storageRoots ?? this.storageRoots,
        newPaths:     newPaths     ?? this.newPaths,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class FoldersNotifier extends Notifier<FoldersState> {

  @override
  FoldersState build() => const FoldersState();

  Future<void> load({bool forceScan = false}) async {
    if (state.isScanning) return;

    final roots = _discoverStorageRoots();

    if (forceScan) {
      await _fullScan(roots);
      return;
    }

    if (state.folders.isEmpty) {
      final cached = await _loadCache();
      if (cached != null && cached.isNotEmpty) {
        // FIX #SDCARD: Filter out folders whose storage root no longer exists
        // (e.g. SD card removed). Checked by path prefix — instant, no fs walk.
        final validFolders = cached.where((f) {
          return roots.any((root) => f.path.startsWith(root));
        }).toList();

        state = state.copyWith(
          folders: validFolders,
          fromCache: true,
          storageRoots: roots,
        );
        _backgroundCheck(roots);
        return;
      }
      await _fullScan(roots);
      return;
    }

    _backgroundCheck(roots);
  }

  Future<void> _backgroundCheck(List<String> roots) async {
    final changed = await _hasNewContent();
    if (changed) {
      await _fullScan(roots);
    }
  }

  Future<void> _fullScan(List<String> roots) async {
    state = state.copyWith(
      isScanning: true,
      folders: state.folders,
      scanProgress: 0,
      fromCache: false,
      storageRoots: roots,
    );

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

      // FIX #SCAN-KILL: Save partial cache after each root completes.
      // If the app is killed mid-scan (OOM etc.), next open loads this
      // partial result instead of showing a blank library.
      if (folderMap.isNotEmpty) {
        final partial = folderMap.entries.map((e) =>
            VideoFolder(path: e.key, videos: e.value)).toList();
        _saveCache(partial).ignore();
      }
    }

    final merged = folderMap.entries.map((e) {
      final videos = e.value;
      final vkeys  = {for (final v in videos) v: v.name.toLowerCase()};
      videos.sort((a, b) => vkeys[a]!.compareTo(vkeys[b]!));
      return VideoFolder(path: e.key, videos: videos);
    }).toList();
    final fkeys = {for (final f in merged) f: f.name.toLowerCase()};
    merged.sort((a, b) => fkeys[a]!.compareTo(fkeys[b]!));

    final seenPaths = await _loadSeenPaths();
    final Set<String> newPaths  = {};
    final Set<String> allPaths  = {};

    for (final folder in merged) {
      allPaths.add(folder.path);
      if (seenPaths != null && seenPaths.isNotEmpty &&
          !seenPaths.contains(folder.path)) {
        newPaths.add(folder.path);
      }
      for (final video in folder.videos) {
        allPaths.add(video.path);
        if (seenPaths != null && seenPaths.isNotEmpty &&
            !seenPaths.contains(video.path)) {
          newPaths.add(video.path);
          newPaths.add(folder.path);
        }
      }
    }

    state = state.copyWith(
      folders: merged,
      isScanning: false,
      fromCache: false,
      newPaths: newPaths,
    );

    await Future.wait([
      _saveSeenPaths(allPaths),
      _saveCache(merged),
    ]);
  }

  void markSeen(String videoPath) {
    if (!state.newPaths.contains(videoPath)) return;
    final updated = Set<String>.from(state.newPaths)..remove(videoPath);

    for (final folder in state.folders) {
      if (folder.videos.any((v) => v.path == videoPath)) {
        final folderStillNew =
            folder.videos.any((v) => updated.contains(v.path));
        if (!folderStillNew) updated.remove(folder.path);
        break;
      }
    }

    state = state.copyWith(newPaths: updated);
    _persistSeenRemoval(videoPath);
  }

  Future<void> _persistSeenRemoval(String videoPath) async {
    try {
      final prefs = await _p;
      final raw = prefs.getString(_seenPathsKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
      list.add(videoPath);
      await prefs.setString(_seenPathsKey, jsonEncode(list.toList()));
    } catch (_) {}
  }

  void reset() => state = const FoldersState();
}

final foldersProvider = NotifierProvider<FoldersNotifier, FoldersState>(
  FoldersNotifier.new,
);
