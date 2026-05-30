import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/video_file.dart';
import '../models/video_folder.dart';
import '../presentation/providers/folders_provider.dart';
import 'folder_videos_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  final void Function(VideoFile) onOpenVideo;
  const LibraryScreen({super.key, required this.onOpenVideo});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  bool _permissionGranted = false;
  bool _checkingPermission = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsAndLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Auto-detect new files when user returns to the app (e.g. after downloading)
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed && _permissionGranted) {
      // load() with forceScan:false → does a quick diff, only rescans if
      // something actually changed (new folder / new file count)
      ref.read(foldersProvider.notifier).load(forceScan: false);
    }
  }

  Future<void> _checkPermissionsAndLoad() async {
    setState(() => _checkingPermission = true);

    final manageStatus    = await Permission.manageExternalStorage.request();
    final storageStatus   = await Permission.storage.request();
    final mediaVideoStatus = await Permission.videos.request();

    if (manageStatus.isGranted ||
        storageStatus.isGranted ||
        mediaVideoStatus.isGranted) {
      if (mounted) {
        setState(() {
          _permissionGranted = true;
          _checkingPermission = false;
        });
      }
      ref.read(foldersProvider.notifier).load(forceScan: false);
    } else {
      if (mounted) {
        setState(() {
          _permissionGranted = false;
          _checkingPermission = false;
        });
      }
    }
  }

  void _openFolder(VideoFolder folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FolderVideosScreen(folder: folder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_checkingPermission) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFE8FF00)));
    }

    if (!_permissionGranted) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.security, size: 48, color: Color(0xFF2A2A2A)),
            const SizedBox(height: 16),
            const Text('Storage Permission Required',
                style: TextStyle(fontSize: 14, color: Color(0xFF555555))),
            const SizedBox(height: 6),
            const Text('We need access to scan your device for videos',
                style: TextStyle(fontSize: 12, color: Color(0xFF333333))),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _checkPermissionsAndLoad,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE8FF00))),
                child: const Text('GRANT PERMISSION',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE8FF00),
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ),
          ],
        ),
      );
    }

    final foldersState = ref.watch(foldersProvider);

    // Show storage roots in the header when multiple found
    final hasMultiStorage = foldersState.storageRoots.length > 1;

    if (foldersState.isScanning && foldersState.folders.isEmpty) {
      // First-time scan: show full loading screen
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFE8FF00)),
            const SizedBox(height: 20),
            const Text(
              'SCANNING DEVICE...',
              style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFE8FF00),
                  letterSpacing: 2,
                  fontFamily: 'monospace'),
            ),
            if (hasMultiStorage) ...[
              const SizedBox(height: 6),
              Text(
                '${foldersState.storageRoots.length} storages',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF555555), fontFamily: 'monospace'),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${foldersState.scanProgress} videos found',
              style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
            ),
          ],
        ),
      );
    }

    final folders = foldersState.folders;

    if (!foldersState.isScanning && folders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off_outlined,
                size: 48, color: Color(0xFF2A2A2A)),
            const SizedBox(height: 16),
            const Text('No Video Folders Found',
                style: TextStyle(fontSize: 14, color: Color(0xFF555555))),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () =>
                  ref.read(foldersProvider.notifier).load(forceScan: true),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE8FF00))),
                child: const Text('SCAN NOW',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFE8FF00),
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Header bar ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E)))),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${folders.length} FOLDER${folders.length == 1 ? '' : 'S'}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF555555),
                        fontFamily: 'monospace',
                        letterSpacing: 2),
                  ),
                  if (hasMultiStorage)
                    Text(
                      '${foldersState.storageRoots.length} STORAGE${foldersState.storageRoots.length == 1 ? '' : 'S'} SCANNED',
                      style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF3A3A3A),
                          fontFamily: 'monospace',
                          letterSpacing: 1),
                    ),
                ],
              ),
              const Spacer(),
              // Scanning indicator (shown while background rescan is running
              // but old results are still displayed)
              if (foldersState.isScanning)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        color: Color(0xFFE8FF00), strokeWidth: 1.5),
                  ),
                ),
              if (foldersState.fromCache && !foldersState.isScanning)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text('CACHED',
                      style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF3A3A3A),
                          fontFamily: 'monospace',
                          letterSpacing: 1)),
                ),
              TextButton(
                onPressed: foldersState.isScanning
                    ? null
                    : () => ref
                        .read(foldersProvider.notifier)
                        .load(forceScan: true),
                child: Text(
                  'RESCAN',
                  style: TextStyle(
                      fontSize: 10,
                      color: foldersState.isScanning
                          ? const Color(0xFF333333)
                          : const Color(0xFF555555),
                      letterSpacing: 1),
                ),
              ),
            ],
          ),
        ),

        // ── Folder list ──
        Expanded(
          child: ListView.builder(
            itemExtent: 69,
            itemCount: folders.length,
            itemBuilder: (_, i) {
              final folder = folders[i];
              // Show a small storage badge when multiple storages found
              final isExternal = hasMultiStorage &&
                  !folder.path.contains('/emulated/');
              return InkWell(
                onTap: () => _openFolder(folder),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Color(0xFF1A1A1A)))),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Icon(Icons.folder,
                              size: 40,
                              color: isExternal
                                  ? const Color(0xFF004444)
                                  : const Color(0xFF444400)),
                          if (isExternal)
                            const Positioned(
                              right: 0,
                              bottom: 0,
                              child: Icon(Icons.sd_card,
                                  size: 14, color: Color(0xFF00AAAA)),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              folder.name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '${folder.videoCount} video${folder.videoCount == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF777777)),
                                ),
                                if (isExternal) ...[
                                  const SizedBox(width: 8),
                                  const Text('SD CARD',
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF00AAAA),
                                          fontFamily: 'monospace',
                                          letterSpacing: 1)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 20, color: Color(0xFF333333)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
