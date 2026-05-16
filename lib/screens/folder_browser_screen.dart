import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/video_folder.dart';
import '../presentation/providers/folders_provider.dart';
import 'folder_videos_screen.dart';

class FolderBrowserScreen extends ConsumerWidget {
  const FolderBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(foldersProvider);
    final notifier = ref.read(foldersProvider.notifier);

    Future<void> pickAndScan() async {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose folder to scan',
      );
      if (path != null) {
        notifier.setRoot(path);
      }
    }

    void openFolder(VideoFolder folder) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FolderVideosScreen(folder: folder),
        ),
      );
    }

    // ── Empty state: no folder chosen yet ──
    if (state.rootPath == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_outlined,
                size: 48, color: Color(0xFF2A2A2A)),
            const SizedBox(height: 16),
            const Text('Find folders with videos',
                style: TextStyle(fontSize: 14, color: Color(0xFF555555))),
            const SizedBox(height: 6),
            const Text('Choose a root folder to scan',
                style: TextStyle(fontSize: 12, color: Color(0xFF333333))),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: pickAndScan,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE8FF00)),
                ),
                child: const Text('CHOOSE FOLDER',
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

    // ── Scanning state ──
    if (state.isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFE8FF00)),
            const SizedBox(height: 20),
            const Text(
              'SCANNING...',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFE8FF00),
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.scanProgress} videos found',
              style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
            ),
          ],
        ),
      );
    }

    // ── No folders found ──
    if (state.folders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off_outlined,
                size: 40, color: Color(0xFF2A2A2A)),
            const SizedBox(height: 14),
            const Text('No video folders found',
                style: TextStyle(fontSize: 13, color: Color(0xFF555555))),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: pickAndScan,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF444444)),
                ),
                child: const Text('CHOOSE DIFFERENT FOLDER',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF888888),
                      letterSpacing: 1.5,
                    )),
              ),
            ),
          ],
        ),
      );
    }

    // ── Folder list ──
    return Column(
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined,
                  size: 15, color: Color(0xFFE8FF00)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.rootPath!.split(RegExp(r'[/\\]')).lastWhere(
                        (seg) => seg.isNotEmpty,
                        orElse: () => state.rootPath!,
                      ),
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE0E0E0),
                      letterSpacing: 0.3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${state.folders.length} folder${state.folders.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF555555),
                    fontFamily: 'monospace'),
              ),
              TextButton(
                onPressed: pickAndScan,
                child: const Text('RESCAN',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF555555),
                        letterSpacing: 1)),
              ),
            ],
          ),
        ),

        // Folder tiles
        Expanded(
          child: ListView.builder(
            itemCount: state.folders.length,
            itemBuilder: (_, i) {
              final folder = state.folders[i];
              return _FolderTile(
                folder: folder,
                onTap: () => openFolder(folder),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Folder Tile ──────────────────────────────────────────────────────────────

class _FolderTile extends StatelessWidget {
  final VideoFolder folder;
  final VoidCallback onTap;

  const _FolderTile({required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
        ),
        child: Row(
          children: [
            // Folder icon badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.folder_rounded,
                      size: 28, color: Color(0xFF444400)),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      color: const Color(0xFF0A0A0A),
                      child: Text(
                        '${folder.videoCount}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFFE8FF00),
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFFE0E0E0)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        '${folder.videoCount} video${folder.videoCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFE8FF00),
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        folder.totalSizeLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF555555),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: Color(0xFF333333)),
          ],
        ),
      ),
    );
  }
}
