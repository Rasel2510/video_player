import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/video_entity.dart';
import '../providers/dependency_providers.dart';
import '../providers/recents_provider.dart';
import 'browser_screen.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'recents_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _openVideo(VideoEntity video) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(video: video)),
    ).then((_) => ref.invalidate(recentsProvider));
  }

  Future<void> _pickSingleVideo() async {
    final video = await ref.read(pickVideoUseCaseProvider).call();
    if (video != null && mounted) _openVideo(video);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
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
          RecentsScreen(
            onOpenVideo: _openVideo,
            onPickFile: _pickSingleVideo,
          ),
          LibraryScreen(onOpenVideo: _openVideo),
          BrowserScreen(onOpenVideo: _openVideo),
        ],
      ),
    );
  }
}
