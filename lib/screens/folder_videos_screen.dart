import 'package:flutter/material.dart';
import '../models/video_file.dart';
import '../models/video_folder.dart';
import '../services/recent_files_service.dart';
import '../widgets/video_tile.dart';
import 'player_screen.dart';

class FolderVideosScreen extends StatelessWidget {
  final VideoFolder folder;

  const FolderVideosScreen({super.key, required this.folder});

  void _openVideo(BuildContext context, VideoFile vf) {
    RecentFilesService.addRecent(vf);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(filePath: vf.path, fileName: vf.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFFAAAAAA)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              folder.name,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              '${folder.videoCount} video${folder.videoCount == 1 ? '' : 's'} · ${folder.totalSizeLabel}',
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF555555),
                  letterSpacing: 0.5),
            ),
          ],
        ),
      ),
      body: ListView.builder(
        itemExtent: 65, // Fixed height optimization
        itemCount: folder.videos.length,
        itemBuilder: (_, i) {
          final vf = folder.videos[i];
          return VideoTile(
            video: vf,
            onTap: () => _openVideo(context, vf),
          );
        },
      ),
    );
  }
}
