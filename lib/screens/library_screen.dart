import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/video_file.dart';
import '../services/folder_scanner.dart';
import '../services/recent_files_service.dart';
import '../widgets/video_tile.dart';


class LibraryScreen extends StatefulWidget {
  final void Function(VideoFile) onOpenVideo;
  const LibraryScreen({super.key, required this.onOpenVideo});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  String? _scanPath;
  List<VideoFile> _videos = [];
  bool _scanning = false;
  int _scanProgress = 0;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose folder to scan',
    );
    if (path == null || !mounted) return;

    setState(() {
      _scanPath = path;
      _scanning = true;
      _scanProgress = 0;
      _videos = [];
    });

    final videos = await FolderScanner.scanRecursive(path, onProgress: (n) {
      if (mounted) setState(() => _scanProgress = n);
    });

    if (mounted) {
      setState(() {
        _videos = videos;
        _scanning = false;
      });
    }
  }

  List<VideoFile> get _filtered {
    if (_searchQuery.isEmpty) return _videos;
    return _videos
        .where((v) =>
            v.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  String _folderName(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.lastWhere((p) => p.isNotEmpty, orElse: () => path);
  }

  void _openVideo(VideoFile vf) {
    RecentFilesService.addRecent(vf);
    widget.onOpenVideo(vf);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_scanPath == null) {
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
              onTap: _pickFolder,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
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

    if (_scanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFE8FF00)),
            const SizedBox(height: 20),
            const Text(
              'SCANNING...',
              style: TextStyle(
                fontSize: 11, color: Color(0xFFE8FF00),
                letterSpacing: 2, fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_scanProgress videos found',
              style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
            ),
          ],
        ),
      );
    }

    final filtered = _filtered;

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
                  _folderName(_scanPath!),
                  style: const TextStyle(
                    fontSize: 12, color: Color(0xFFE0E0E0), letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('${_videos.length} videos',
                  style: const TextStyle(
                    fontSize: 11, color: Color(0xFF555555), fontFamily: 'monospace',
                  )),
              TextButton(
                onPressed: _pickFolder,
                child: const Text('CHANGE',
                    style: TextStyle(
                      fontSize: 10, color: Color(0xFF555555), letterSpacing: 1,
                    )),
              ),
            ],
          ),
        ),

        // Search bar
        if (_videos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13, color: Color(0xFFE0E0E0)),
              decoration: InputDecoration(
                hintText: 'Search videos...',
                hintStyle: const TextStyle(color: Color(0xFF444444), fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF555555)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Color(0xFF555555)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
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
                  borderSide: BorderSide(color: Color(0xFFE8FF00), width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

        // Results count
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(children: [
              Text('${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF555555), fontFamily: 'monospace')),
            ]),
          ),

        // Video list
        Expanded(
          child: _videos.isEmpty
              ? const Center(
                  child: Text('No videos found in this folder',
                      style: TextStyle(fontSize: 13, color: Color(0xFF555555))),
                )
              : filtered.isEmpty
                  ? const Center(
                      child: Text('No results',
                          style: TextStyle(fontSize: 13, color: Color(0xFF555555))),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => VideoTile(
                        video: filtered[i],
                        onTap: () => _openVideo(filtered[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}
