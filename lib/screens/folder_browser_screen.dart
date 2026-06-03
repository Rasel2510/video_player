
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/video_file.dart';
import '../services/folder_scanner.dart';
import '../services/recent_files_service.dart';
import '../widgets/video_tile.dart';

class FolderBrowserScreen extends StatefulWidget {
  final void Function(VideoFile) onOpenVideo;
  const FolderBrowserScreen({super.key, required this.onOpenVideo});

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen>
    with AutomaticKeepAliveClientMixin {
  // Breadcrumb stack: list of directory paths
  final List<String> _breadcrumbs = [];
  FolderContents? _contents;
  bool _loading = false;
  String? _rootPath;

  @override
  bool get wantKeepAlive => true;

  // String? get _currentPath =>
  //     _breadcrumbs.isNotEmpty ? _breadcrumbs.last : null;

  Future<void> _pickRoot() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose root folder',
    );
    if (path == null || !mounted) return;
    setState(() {
      _rootPath = path;
      _breadcrumbs.clear();
      _breadcrumbs.add(path);
    });
    _loadDir(path);
  }

  Future<void> _loadDir(String path) async {
    setState(() { _loading = true; _contents = null; });
    // Run on separate isolate-friendly call (listSync is fast enough)
    final contents = await Future(() => FolderScanner.listDirectory(path));
    if (mounted) setState(() { _contents = contents; _loading = false; });
  }

  void _navigateTo(String dirPath) {
    _breadcrumbs.add(dirPath);
    _loadDir(dirPath);
  }

  void _navigateUp() {
    if (_breadcrumbs.length > 1) {
      _breadcrumbs.removeLast();
      _loadDir(_breadcrumbs.last);
    }
  }

  void _navigateToBreadcrumb(int index) {
    while (_breadcrumbs.length > index + 1) {
      _breadcrumbs.removeLast();
    }
    _loadDir(_breadcrumbs.last);
  }

  void _openVideo(VideoFile vf) {
    RecentFilesService.addRecent(vf);
    widget.onOpenVideo(vf);
  }

  String _dirName(String path) {
    return p.basename(path).isEmpty ? path : p.basename(path);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_rootPath == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_outlined,
                size: 48, color: Color(0xFF2A2A2A)),
            const SizedBox(height: 16),
            Text('Browse your device folders',
                style: TextStyle(fontSize: 14, color: context.colors.textSecondary)),
            const SizedBox(height: 6),
            const Text('Navigate directories to find videos',
                style: TextStyle(fontSize: 12, color: Color(0xFF333333))),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _pickRoot,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: context.colors.accent),
                ),
                child: Text('CHOOSE ROOT FOLDER',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.accent,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── BREADCRUMB BAR ──
        Container(
          height: 44,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
          ),
          child: Row(
            children: [
              // Up button
              if (_breadcrumbs.length > 1)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      size: 15, color: Color(0xFF888888)),
                  onPressed: _navigateUp,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),

              // Scrollable breadcrumbs
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _breadcrumbs.length,
                  separatorBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.chevron_right,
                        size: 14, color: Color(0xFF333333)),
                  ),
                  itemBuilder: (_, i) {
                    final isLast = i == _breadcrumbs.length - 1;
                    return Center(
                      child: GestureDetector(
                        onTap: isLast ? null : () => _navigateToBreadcrumb(i),
                        child: Text(
                          _dirName(_breadcrumbs[i]),
                          style: TextStyle(
                            fontSize: 12,
                            color: isLast
                                ?  context.colors.accent
                                :  context.colors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Change root
              IconButton(
                icon: Icon(Icons.drive_folder_upload_outlined,
                    size: 18, color: context.colors.textSecondary),
                tooltip: 'Change root folder',
                onPressed: _pickRoot,
              ),
            ],
          ),
        ),

        // ── CONTENT ──
        Expanded(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(color: context.colors.accent))
              : _contents == null
                  ? const SizedBox()
                  : _buildContents(),
        ),
      ],
    );
  }

  Widget _buildContents() {
    final dirs = _contents!.dirs;
    final videos = _contents!.videos;
    final total = dirs.length + videos.length;

    if (total == 0) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_outlined, size: 36, color: Color(0xFF2A2A2A)),
            SizedBox(height: 12),
            Text('Empty folder',
                style: TextStyle(fontSize: 13, color: context.colors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: dirs.length + videos.length + (dirs.isNotEmpty && videos.isNotEmpty ? 1 : 0),
      itemBuilder: (_, i) {
        // Directories first
        if (i < dirs.length) {
          final dir = dirs[i];
          final name = p.basename(dir.path);
          return _DirTile(
            name: name,
            path: dir.path,
            onTap: () => _navigateTo(dir.path),
          );
        }

        // Divider between dirs and videos
        if (dirs.isNotEmpty && videos.isNotEmpty && i == dirs.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(children: [
              Text(
                '${videos.length} VIDEO${videos.length == 1 ? '' : 'S'}',
                style: TextStyle(
                  fontSize: 10, color: context.colors.textSecondary,
                  letterSpacing: 2, fontFamily: 'monospace',
                ),
              ),
            ]),
          );
        }

        final videoIndex = dirs.isNotEmpty && videos.isNotEmpty
            ? i - dirs.length - 1
            : i - dirs.length;

        final vf = videos[videoIndex];
        return VideoTile(
          video: vf,
          onTap: () => _openVideo(vf),
        );
      },
    );
  }
}

class _DirTile extends StatelessWidget {
  final String name;
  final String path;
  final VoidCallback onTap;

  const _DirTile({
    required this.name,
    required this.path,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.divider)),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_outlined,
                size: 20, color: Color(0xFF666600)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 13, color: Color(0xFFCCCCCC)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF333333)),
          ],
        ),
      ),
    );
  }
}