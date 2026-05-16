import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../domain/entities/video_entity.dart';
import '../providers/player_provider.dart';
import '../providers/recents_provider.dart';
import '../widgets/player/player_controls_overlay.dart';
import '../widgets/player/speed_sheet.dart';
import '../widgets/player/volume_sheet.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final VideoEntity video;

  const PlayerScreen({super.key, required this.video});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(playerProvider.notifier).init(widget.video.path);
      await ref.read(recentsProvider.notifier).add(widget.video);
    });
  }

  @override
  void dispose() {
    ref.read(playerProvider.notifier).dispose();
    super.dispose();
  }

  void _showSpeedSheet(BuildContext context, double currentSpeed) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SpeedSheet(
        currentSpeed: currentSpeed,
        onSelect: (s) => ref.read(playerProvider.notifier).setSpeed(s),
      ),
    );
  }

  void _showVolumeSheet(BuildContext context, double currentVolume) {
    showModalBottomSheet(
      context: context,
      builder: (_) => VolumeSheet(
        volume: currentVolume,
        onChanged: (v) => ref.read(playerProvider.notifier).setVolume(v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: playerState.controlsVisible
            ? notifier.hideControls
            : notifier.showControls,
        onDoubleTapDown: (details) {
          final w = MediaQuery.of(context).size.width;
          details.globalPosition.dx < w / 2
              ? notifier.seekRelative(-10)
              : notifier.seekRelative(10);
        },
        child: Stack(
          children: [
            // Video
            Positioned.fill(child: _VideoView(playerState: playerState,
                controller: notifier.controller)),

            // Controls overlay
            if (playerState.isInitialized)
              AnimatedOpacity(
                opacity: playerState.controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !playerState.controlsVisible,
                  child: PlayerControlsOverlay(
                    playerState: playerState,
                    fileName: widget.video.name,
                    onBack: () => Navigator.pop(context),
                    onTogglePlay: notifier.togglePlay,
                    onCycleFitMode: notifier.cycleFitMode,
                    onShowSpeed: () =>
                        _showSpeedSheet(context, playerState.playbackSpeed),
                    onShowVolume: () =>
                        _showVolumeSheet(context, playerState.volume),
                    onSeekBack: () => notifier.seekRelative(-10),
                    onSeekForward: () => notifier.seekRelative(10),
                    onToggleFullscreen: notifier.toggleFullscreen,
                    onSeekStart: notifier.beginSeek,
                    onSeekUpdate: notifier.updateSeek,
                    onSeekEnd: notifier.endSeek,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoView extends StatelessWidget {
  final PlayerState playerState;
  final VideoPlayerController? controller;

  const _VideoView({required this.playerState, required this.controller});

  BoxFit _boxFit() => switch (playerState.fitMode) {
        FitMode.contain => BoxFit.contain,
        FitMode.cover => BoxFit.cover,
        FitMode.fill => BoxFit.fill,
        FitMode.natural => BoxFit.scaleDown,
      };

  @override
  Widget build(BuildContext context) {
    if (!playerState.isInitialized || controller == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFE8FF00),
        ),
      );
    }
    return FittedBox(
      fit: _boxFit(),
      child: SizedBox(
        width: controller!.value.size.width,
        height: controller!.value.size.height,
        child: VideoPlayer(controller!),
      ),
    );
  }
}
