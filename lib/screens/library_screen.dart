import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/video_file.dart';
import '../domain/entities/video_entity.dart';
import '../presentation/providers/library_provider.dart';
import '../widgets/video_tile.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  final void Function(VideoFile) onOpenVideo;
  const LibraryScreen({super.key, required this.onOpenVideo});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openVideo(VideoEntity v) {
    widget.onOpenVideo(VideoFile(
      path: v.path,
      name: v.name,
      size: v.sizeBytes,
      modified: v.lastModified,
    ));
  }

  String _folderName(String? path) {
    if (path == null) return '';
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.lastWhere((p) => p.isNotEmpty, orElse: () => path);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);

    if (state.scanPath == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_library_outlined,
                size: 48, color: Color(0xFF2A2A2A)),
            const SizedBox(height: 16),
            const Text('Scan a folder for videos',
                style: TextStyle(fontSize: 14, color: Color(0xFF555555))),
            const SizedBox(height: 6),
            const Text('All video files inside will be listed',
                style: TextStyle(fontSize: 12, color: Color(0xFF333333))),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: notifier.pickAndScan,
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

    final filtered = state.filtered;

    return Column(
      children: [
        // Folder info + change button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined,
                  size: 16, color: Color(0xFFE8FF00)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _folderName(state.scanPath),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFE0E0E0),
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('${state.videos.length} videos',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF555555),
                    fontFamily: 'monospace',
                  )),
              TextButton(
                onPressed: notifier.pickAndScan,
                child: const Text('CHANGE',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF555555),
                      letterSpacing: 1,
                    )),
              ),
            ],
          ),
        ),

        // Search bar
        if (state.videos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13, color: Color(0xFFE0E0E0)),
              decoration: InputDecoration(
                hintText: 'Search videos...',
                hintStyle:
                    const TextStyle(color: Color(0xFF444444), fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: Color(0xFF555555)),
                suffixIcon: state.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            size: 16, color: Color(0xFF555555)),
                        onPressed: () {
                          _searchCtrl.clear();
                          notifier.clearSearch();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF161616),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Color(0xFF2A2A2A)),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Color(0xFF2A2A2A)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide:
                      BorderSide(color: Color(0xFFE8FF00), width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
              onChanged: notifier.updateSearch,
            ),
          ),

        // Results count
        if (state.searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(children: [
              Text(
                  '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF555555),
                      fontFamily: 'monospace')),
            ]),
          ),

        // Video list
        Expanded(
          child: state.videos.isEmpty
              ? const Center(
                  child: Text('No videos found in this folder',
                      style: TextStyle(fontSize: 13, color: Color(0xFF555555))),
                )
              : filtered.isEmpty
                  ? const Center(
                      child: Text('No results',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF555555))),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final v = filtered[i];
                        return VideoTile(
                          video: VideoFile(
                            path: v.path,
                            name: v.name,
                            size: v.sizeBytes,
                            modified: v.lastModified,
                          ),
                          onTap: () => _openVideo(v),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
