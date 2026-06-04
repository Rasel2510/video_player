import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/video_file.dart';
import '../../models/video_folder.dart';
import '../../services/folder_scanner.dart';

// ── Storage root discovery ────────────────────────────────────────────────────

// Module-level SharedPreferences cache — shared by top-level helpers and
// FoldersNotifier so SharedPreferences.getInstance() is called only once.
SharedPreferences? _cachedPrefs;
Future<SharedPreferences> get _p async =>
    _cachedPrefs ??= await SharedPreferences.getInstance();

/// Sentinel exception used as a fast-path exit signal inside the isolate
/// when a filesystem change is detected during a quick scan.
class _ChangedSignal implements Exception {
  const _ChangedSignal();
}

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

// Paths seen by the user (acknowledged). New ones get a "NEW" badge.
const _seenPathsKey     = 'folder_scan_seen_paths_v1';
const _seenPathsInitKey = 'folder_scan_seen_paths_init_v1'; // true once written

/// Returns null on fresh install (never scanned before).
/// Returns the set of previously seen paths on subsequent scans.
Future<Set<String>?> _loadSeenPaths() async {
  try {
    final prefs = await _p;
    // If we have never written seen-paths, this is a fresh install.
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

Future<List<VideoFolder>?> _loadCache() async {
  try {
    final prefs = await _p;
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
    final prefs = await _p;
    await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(_cacheKey, jsonEncode(folders.map(_folderToMap).toList()));
    // Save snapshot: Map<folderPath, videoCount>
    final snapshot = {for (final f in folders) f.path: f.videoCount};
    await prefs.setString(_snapshotKey, jsonEncode(snapshot));
  } catch (_) {}
}

/// Quick check: scan folder paths & counts WITHOUT reading file metadata.
/// Returns true if anything changed vs the cached snapshot.
///
/// FIX #OPT-7: Previously _quickScan used `await for (dir.list())` on the
/// main isolate, which still processes the entire directory tree via async
/// microtasks on the UI thread.  For deep trees with thousands of files this
/// clogs the event loop.  The walk is now offloaded to a dedicated isolate
/// so the UI thread stays completely free during the check.
Future<bool> _hasNewContent() async {
  try {
    final prefs = await _p;
    final rawSnapshot = prefs.getString(_snapshotKey);
    if (rawSnapshot == null) return true; // no snapshot → treat as changed

    final oldSnapshot = Map<String, int>.from(
        (jsonDecode(rawSnapshot) as Map)
            .map((k, v) => MapEntry(k as String, v as int)));

    final roots = _discoverStorageRoots();

    // Spawn one isolate to check all roots; it sends true/false back.
    final port = ReceivePort();
    await Isolate.spawn(
      _isolateQuickCheck,
      _QuickCheckData(roots, oldSnapshot, port.sendPort),
    );
    final changed = await port.first as bool;
    return changed;
  } catch (_) {
    return true; // on any error, assume changed → trigger full scan
  }
}

// ── Isolate entry point ───────────────────────────────────────────────────────

class _QuickCheckData {
  final List<String> roots;
  final Map<String, int> snapshot;
  final SendPort sendPort;
  _QuickCheckData(this.roots, this.snapshot, this.sendPort);
}

/// Top-level function required by Isolate.spawn.
void _isolateQuickCheck(_QuickCheckData data) {
  try {
    for (final root in data.roots) {
      _quickScanSync(Directory(root), data.snapshot);
    }
    data.sendPort.send(false); // no changes found
  } catch (e) {
    // _ChangedSignal or any other exception → treat as changed.
    data.sendPort.send(true);
  }
}

/// Synchronous recursive walk inside the isolate.
/// Throws [_ChangedSignal] as a fast-path exit when a change is detected.
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
  final List<String> storageRoots; // all mounted roots found
  /// Paths (folder paths + video file paths) that are new since last scan.
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

    // Precompute sort keys for both videos and folders before sorting.
    final merged = folderMap.entries.map((e) {
      final videos = e.value;
      final vkeys  = {for (final v in videos) v: v.name.toLowerCase()};
      videos.sort((a, b) => vkeys[a]!.compareTo(vkeys[b]!));
      return VideoFolder(path: e.key, videos: videos);
    }).toList();
    final fkeys = {for (final f in merged) f: f.name.toLowerCase()};
    merged.sort((a, b) => fkeys[a]!.compareTo(fkeys[b]!));

    // Single pass — compute newPaths and allPaths simultaneously.
    // null seenPaths = fresh install; save all as seen, no NEW badges.
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
          newPaths.add(folder.path); // mark parent folder new too
        }
      }
    }

    state = state.copyWith(
      folders: merged,
      isScanning: false,
      fromCache: false,
      newPaths: newPaths,
    );

    // Save seen-paths and folder cache in parallel.
    await Future.wait([
      _saveSeenPaths(allPaths),
      _saveCache(merged),
    ]);
  }

  /// Called when a user opens a video. Removes the video path from newPaths,
  /// and also removes the parent folder if none of its videos are new anymore.
  void markSeen(String videoPath) {
    if (!state.newPaths.contains(videoPath)) return;
    final updated = Set<String>.from(state.newPaths)..remove(videoPath);

    // Find the parent folder — if it has no more new videos, remove it too.
    for (final folder in state.folders) {
      if (folder.videos.any((v) => v.path == videoPath)) {
        final folderStillNew =
            folder.videos.any((v) => updated.contains(v.path));
        if (!folderStillNew) updated.remove(folder.path);
        break;
      }
    }

    state = state.copyWith(newPaths: updated);

    // Persist so the badge doesn't come back after app restart.
    _persistSeenRemoval(videoPath);
  }

  Future<void> _persistSeenRemoval(String videoPath) async {
    try {
      final prefs = await _p;
      final raw = prefs.getString(_seenPathsKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
      list.add(videoPath); // ensure it's marked seen on disk too
      await prefs.setString(_seenPathsKey, jsonEncode(list.toList()));
    } catch (_) {}
  }

  void reset() => state = const FoldersState();
}

final foldersProvider = NotifierProvider<FoldersNotifier, FoldersState>(
  FoldersNotifier.new,
);
