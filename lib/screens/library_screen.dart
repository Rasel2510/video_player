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
    with AutomaticKeepAliveClientMixin {
  bool _permissionGranted = false;
  bool _checkingPermission = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndScan();
  }

  Future<void> _checkPermissionsAndScan() async {
    setState(() => _checkingPermission = true);

    // Request permissions. On Android 11+ we often need manageExternalStorage to see all folders.
    final manageStatus = await Permission.manageExternalStorage.request();
    final storageStatus = await Permission.storage.request();
    final mediaVideoStatus = await Permission.videos.request();

    if (manageStatus.isGranted || storageStatus.isGranted || mediaVideoStatus.isGranted) {
      if (mounted) setState(() { _permissionGranted = true; _checkingPermission = false; });
      // Start scanning the standard Android external storage root
      ref.read(foldersProvider.notifier).setRoot('/storage/emulated/0');
    } else {
      if (mounted) setState(() { _permissionGranted = false; _checkingPermission = false; });
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
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE8FF00)));
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
              onTap: _checkPermissionsAndScan,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE8FF00)),
                ),
                child: const Text('GRANT PERMISSION',
                    style: TextStyle(
                      fontSize: 11, color: Color(0xFFE8FF00),
                      letterSpacing: 2, fontWeight: FontWeight.bold,
                    )),
              ),
            ),
          ],
        ),
      );
    }

    final foldersState = ref.watch(foldersProvider);

    if (foldersState.isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFE8FF00)),
            const SizedBox(height: 20),
            const Text(
              'SCANNING DEVICE...',
              style: TextStyle(
                fontSize: 11, color: Color(0xFFE8FF00),
                letterSpacing: 2, fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${foldersState.scanProgress} videos found so far',
              style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
            ),
          ],
        ),
      );
    }

    final folders = foldersState.folders;

    if (folders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off_outlined, size: 48, color: Color(0xFF2A2A2A)),
            const SizedBox(height: 16),
            const Text('No Video Folders Found',
                style: TextStyle(fontSize: 14, color: Color(0xFF555555))),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => ref.read(foldersProvider.notifier).setRoot('/storage/emulated/0'),
              child: const Text('RESCAN',
                  style: TextStyle(
                    fontSize: 11, color: Color(0xFFE8FF00),
                    letterSpacing: 2, fontWeight: FontWeight.bold,
                  )),
            )
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
          ),
          child: Row(
            children: [
              Text('${folders.length} FOLDER${folders.length == 1 ? '' : 'S'}',
                  style: const TextStyle(
                    fontSize: 11, color: Color(0xFF555555), fontFamily: 'monospace', letterSpacing: 2,
                  )),
              const Spacer(),
              TextButton(
                onPressed: () => ref.read(foldersProvider.notifier).setRoot('/storage/emulated/0'),
                child: const Text('RESCAN',
                    style: TextStyle(
                      fontSize: 10, color: Color(0xFF555555), letterSpacing: 1,
                    )),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: folders.length,
            itemBuilder: (_, i) {
              final folder = folders[i];
              return InkWell(
                onTap: () => _openFolder(folder),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder, size: 40, color: Color(0xFF444400)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              folder.name,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${folder.videoCount} video${folder.videoCount == 1 ? '' : 's'}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF777777)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 20, color: Color(0xFF333333)),
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
