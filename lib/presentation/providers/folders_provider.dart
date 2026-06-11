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

const _cacheKey = 'folder_scan_cache_v2';
const _cacheTimeKey = 'folder_scan_time_v2';

// FIX #TTL: Removed 12-hour TTL — cache is now permanent and only replaced
// when a real filesystem change is detected by the background snapshot check.

const _snapshotKey = 'folder_scan_snapshot_v2';
const _seenPathsKey = 'folder_scan_seen_paths_v1';
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
    // FIX #3: Write the init flag FIRST. If the app is killed between the two
    // writes, next open reads an empty seenPaths (safe) rather than treating
    // the library as uninitialised and badging every video as new.
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

// FIX #ATOMIC: cache and snapshot are always written together.
Future<void> _saveCache(List<VideoFolder> folders) async {
  try {
    final prefs = await _p;
    await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(
        _cacheKey, jsonEncode(folders.map(_folderToMap).toList()));
    final snapshot = {for (final f in folders) f.path: f.videoCount};
    await prefs.setString(_snapshotKey, jsonEncode(snapshot));
  } catch (_) {}
}

Future<bool> _hasNewContent() async {
  try {
    final prefs = await _p;
    final rawSnapshot = prefs.getString(_snapshotKey);
    if (rawSnapshot == null) return true;

    final oldSnapshot = Map<String, int>.from((jsonDecode(rawSnapshot) as Map)
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
      if (cached == null || cached != videoCount) throw const _ChangedSignal();
    }

    for (final sub in subs) {
      _quickScanSync(sub, snapshot);
    }
  } on _ChangedSignal {
    rethrow;
  } catch (_) {}
}

// ── FIX #4: Prune stale paths ─────────────────────────────────────────────────
// seenPaths only ever grows — deleted videos leave their paths in storage
// forever. Intersect with the current scan result to keep the JSON lean.
Set<String> _pruneSeenPaths(Set<String> seen, Set<String> allCurrentPaths) =>
    seen.intersection(allCurrentPaths);

Map<String, dynamic> _folderToMap(VideoFolder f) => {
      'path': f.path,
      'videos': f.videos
          .map((v) => {
                'path': v.path,
                'name': v.name,
                'size': v.size,
                'modified': v.modified.millisecondsSinceEpoch,
              })
          .toList(),
    };

VideoFolder _folderFromMap(Map<String, dynamic> m) => VideoFolder(
      path: m['path'] as String,
      videos: (m['videos'] as List<dynamic>)
          .map((v) => VideoFile(
                path: v['path'] as String,
                name: v['name'] as String,
                size: v['size'] as int,
                modified:
                    DateTime.fromMillisecondsSinceEpoch(v['modified'] as int),
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
    this.folders = const [],
    this.isScanning = false,
    this.scanProgress = 0,
    this.fromCache = false,
    this.storageRoots = const [],
    this.newPaths = const {},
  });

  FoldersState copyWith({
    List<VideoFolder>? folders,
    bool? isScanning,
    int? scanProgress,
    bool? fromCache,
    List<String>? storageRoots,
    Set<String>? newPaths,
  }) =>
      FoldersState(
        folders: folders ?? this.folders,
        isScanning: isScanning ?? this.isScanning,
        scanProgress: scanProgress ?? this.scanProgress,
        fromCache: fromCache ?? this.fromCache,
        storageRoots: storageRoots ?? this.storageRoots,
        newPaths: newPaths ?? this.newPaths,
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
        // FIX #SDCARD: Filter out folders whose storage root no longer exists.
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
    if (changed) await _fullScan(roots);
  }

  Future<void> _fullScan(List<String> roots) async {
    state = state.copyWith(
      isScanning: true,
      folders: state.folders,
      scanProgress: 0,
      fromCache: false,
      storageRoots: roots,
    );

    // FIX #2: Capture which paths are CURRENTLY showing as new in the UI
    // before the scan starts. markSeen() removes a path from state.newPaths
    // immediately (in memory) but _persistSeenRemoval() is async — the path
    // may not be in seenPaths on disk yet when _loadSeenPaths() runs below.
    // Any path absent from preScanNewPaths but absent from the new state.newPaths
    // was dismissed by the user during this session and must NOT be re-badged.
    // We handle this by checking: if a path was NOT in preScanNewPaths and is
    // also NOT in seenPaths on disk, it means markSeen() cleared it in-memory
    // already — so we treat it as seen for this scan pass.
    final preScanNewPaths = Set<String>.from(state.newPaths);

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

      // FIX #SCAN-KILL: Save partial cache after each root so a mid-scan kill
      // doesn't leave the user with a blank library on next open.
      if (folderMap.isNotEmpty) {
        final partial = folderMap.entries
            .map((e) => VideoFolder(path: e.key, videos: e.value))
            .toList();
        _saveCache(partial).ignore();
      }
    }

    final merged = folderMap.entries.map((e) {
      final videos = e.value;
      final vkeys = {for (final v in videos) v: v.name.toLowerCase()};
      videos.sort((a, b) => vkeys[a]!.compareTo(vkeys[b]!));
      return VideoFolder(path: e.key, videos: videos);
    }).toList();
    final fkeys = {for (final f in merged) f: f.name.toLowerCase()};
    merged.sort((a, b) => fkeys[a]!.compareTo(fkeys[b]!));

    final seenPaths = await _loadSeenPaths();

    // FIX #4: Build current path set and prune stale entries from seenPaths.
    final Set<String> allCurrentPaths = {};
    for (final folder in merged) {
      allCurrentPaths.add(folder.path);
      for (final video in folder.videos) {
        allCurrentPaths.add(video.path);
      }
    }
    final Set<String> alreadySeenPaths =
        seenPaths != null ? _pruneSeenPaths(seenPaths, allCurrentPaths) : {};

    final Set<String> newPaths = {};

    for (final folder in merged) {
      // A path is considered new when ALL of these are true:
      //   1. seenPaths is initialised (null = first install → no badges)
      //   2. seenPaths is not empty (empty first scan → no badges)
      //   3. path is not in seenPaths on disk
      //   4. FIX #2: path was in preScanNewPaths OR is not already dismissed
      //      in-session. If it was in preScanNewPaths it is genuinely still
      //      new. If it was NOT in preScanNewPaths it means markSeen() already
      //      removed it before this scan — don't re-badge it.
      final bool initialised = seenPaths != null && seenPaths.isNotEmpty;

      final folderOnDisk = seenPaths?.contains(folder.path) ?? false;
      // Was this folder already dismissed in-session before the scan started?
      // Yes if it was previously in state.newPaths but markSeen cleared it.
      // preScanNewPaths holds what was new BEFORE dismissal — if folder.path
      // is absent from preScanNewPaths AND absent from disk it was dismissed.
      final folderDismissedInSession =
          !folderOnDisk && !preScanNewPaths.contains(folder.path);

      if (initialised && !folderOnDisk && !folderDismissedInSession) {
        newPaths.add(folder.path);
      } else {
        alreadySeenPaths.add(folder.path);
      }

      for (final video in folder.videos) {
        final videoOnDisk = seenPaths?.contains(video.path) ?? false;
        final videoDismissedInSession =
            !videoOnDisk && !preScanNewPaths.contains(video.path);

        if (initialised && !videoOnDisk && !videoDismissedInSession) {
          newPaths.add(video.path);
          newPaths.add(folder.path); // keep folder badge alive too
        } else {
          alreadySeenPaths.add(video.path);
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
      _saveSeenPaths(alreadySeenPaths),
      _saveCache(merged),
    ]);
  }

  // ── Mark a video as seen (user opened it) ─────────────────────────────────

  void markSeen(String videoPath) {
    if (!state.newPaths.contains(videoPath)) return;
    final updated = Set<String>.from(state.newPaths)..remove(videoPath);

    // FIX #1: Also clear + persist the folder path when the last new video
    // in it is watched. Previously only videoPath was written to disk, so the
    // folder path stayed absent from seenPaths and re-badged on next scan.
    String? clearedFolderPath;
    for (final folder in state.folders) {
      if (folder.videos.any((v) => v.path == videoPath)) {
        final folderStillNew =
            folder.videos.any((v) => updated.contains(v.path));
        if (!folderStillNew) {
          updated.remove(folder.path);
          clearedFolderPath = folder.path;
        }
        break;
      }
    }

    state = state.copyWith(newPaths: updated);
    _persistSeenRemoval(videoPath, clearedFolderPath: clearedFolderPath);
  }

  Future<void> _persistSeenRemoval(
    String videoPath, {
    String? clearedFolderPath,
  }) async {
    try {
      final prefs = await _p;
      final raw = prefs.getString(_seenPathsKey);
      if (raw == null) return;
      final set = (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
      set.add(videoPath);
      // FIX #1: persist folder path too when all its videos are now seen.
      if (clearedFolderPath != null) set.add(clearedFolderPath);
      await prefs.setString(_seenPathsKey, jsonEncode(set.toList()));
    } catch (_) {}
  }

  void reset() => state = const FoldersState();
}

final foldersProvider = NotifierProvider<FoldersNotifier, FoldersState>(
  FoldersNotifier.new,
);
