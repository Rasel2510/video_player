
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/video_file.dart';
import '../services/recent_files_service.dart';
import 'player_screen.dart';
import 'folder_browser_screen.dart';
import 'library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<VideoFile> _recents = [];
  bool _loadingRecents = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadRecents();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    final r = await RecentFilesService.getRecents();
    if (mounted) setState(() { _recents = r; _loadingRecents = false; });
  }

  void _openVideo(VideoFile vf) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(filePath: vf.path, fileName: vf.name),
      ),
    ).then((_) => _loadRecents());
  }

  Future<void> _pickSingleVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null && mounted) {
      final f = result.files.single;
      final vf = VideoFile(
        path: f.path!,
        name: f.name,
        size: f.size,
        modified: DateTime.now(),
      );
      await RecentFilesService.addRecent(vf);
      _openVideo(vf);
    }
  }

  Future<void> _removeRecent(String path) async {
    await RecentFilesService.removeRecent(path);
    _loadRecents();
  }

  Future<void> _clearAllRecents() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text('Clear history?',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF888888)))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear',
                  style: TextStyle(color: Color(0xFFE8FF00)))),
        ],
      ),
    );
    if (ok == true) {
      await RecentFilesService.clearAll();
      _loadRecents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFE8FF00), shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            const Text('VIDEO PLAYER'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_outlined, size: 22),
            tooltip: 'Open file',
            onPressed: _pickSingleVideo,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFFE8FF00),
          indicatorWeight: 2,
          labelColor: const Color(0xFFE8FF00),
          unselectedLabelColor: const Color(0xFF555555),
          labelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
          tabs: const [
            Tab(text: 'RECENTS'),
            Tab(text: 'LIBRARY'),
            Tab(text: 'BROWSE'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _RecentsTab(
            recents: _recents,
            loading: _loadingRecents,
            onOpen: _openVideo,
            onRemove: _removeRecent,
            onClearAll: _clearAllRecents,
            onPickFile: _pickSingleVideo,
          ),
          LibraryScreen(onOpenVideo: _openVideo),
          FolderBrowserScreen(onOpenVideo: _openVideo),
        ],
      ),
    );
  }
}

// ── RECENTS TAB ──

class _RecentsTab extends StatelessWidget {
  final List<VideoFile> recents;
  final bool loading;
  final void Function(VideoFile) onOpen;
  final void Function(String) onRemove;
  final VoidCallback onClearAll;
  final VoidCallback onPickFile;

  const _RecentsTab({
    required this.recents,
    required this.loading,
    required this.onOpen,
    required this.onRemove,
    required this.onClearAll,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFE8FF00)));
    }

    if (recents.isEmpty) {
      return _EmptyState(
        icon: Icons.history,
        title: 'No recent videos',
        subtitle: 'Videos you play will appear here',
        actionLabel: 'OPEN A VIDEO',
        onAction: onPickFile,
      );
    }

    return Column(
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
          child: Row(
            children: [
              Text(
                '${recents.length} VIDEO${recents.length == 1 ? '' : 'S'}',
                style: const TextStyle(
                  fontSize: 11, color: Color(0xFF555555),
                  letterSpacing: 2, fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onClearAll,
                child: const Text('CLEAR ALL',
                    style: TextStyle(
                      fontSize: 10, color: Color(0xFF555555), letterSpacing: 1,
                    )),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: recents.length,
            itemBuilder: (_, i) {
              final vf = recents[i];
              return Dismissible(
                key: Key(vf.path),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: const Color(0xFF2A0A0A),
                  child: const Icon(Icons.delete_outline,
                      color: Color(0xFFFF4444), size: 22),
                ),
                onDismissed: (_) => onRemove(vf.path),
                child: _RecentTile(vf: vf, onTap: () => onOpen(vf)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  final VideoFile vf;
  final VoidCallback onTap;
  const _RecentTile({required this.vf, required this.onTap});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: const Icon(Icons.play_circle_outline,
                  color: Color(0xFF444444), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vf.name,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFE0E0E0)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(
                      vf.extension.replaceFirst('.', '').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10, color: Color(0xFFE8FF00),
                        fontFamily: 'monospace', letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(vf.sizeLabel,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF555555), fontFamily: 'monospace')),
                    const Spacer(),
                    Text(_timeAgo(vf.modified),
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF444444), fontFamily: 'monospace')),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF333333)),
          ],
        ),
      ),
    );
  }
}

// ── EMPTY STATE ──

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF2A2A2A)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(fontSize: 14, color: Color(0xFF555555))),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF333333))),
          if (actionLabel != null) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE8FF00)),
                ),
                child: Text(actionLabel!,
                    style: const TextStyle(
                      fontSize: 11, color: Color(0xFFE8FF00),
                      letterSpacing: 2, fontWeight: FontWeight.bold,
                    )),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
