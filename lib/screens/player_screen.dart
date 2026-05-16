import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../presentation/providers/player_provider.dart';
import '../presentation/widgets/player/player_controls_overlay.dart';
import '../presentation/widgets/player/speed_sheet.dart';
import '../presentation/widgets/player/volume_sheet.dart';
import '../presentation/widgets/player/audio_track_sheet.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String filePath;
  final String fileName;

  const PlayerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playerProvider.notifier).init(widget.filePath);
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

  void _showAudioTrackSheet(BuildContext context) {
    final state = ref.read(playerProvider);
    showModalBottomSheet(
      context: context,
      builder: (_) => AudioTrackSheet(
        tracks: state.audioTracks,
        selectedTrack: state.selectedAudioTrack,
        onSelect: (t) => ref.read(playerProvider.notifier).setAudioTrack(t),
      ),
    );
  }

  BoxFit _boxFit(FitMode mode) => switch (mode) {
        FitMode.contain => BoxFit.contain,
        FitMode.cover => BoxFit.cover,
        FitMode.fill => BoxFit.fill,
        FitMode.natural => BoxFit.scaleDown,
      };

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
            // Video View
            if (playerState.isInitialized && notifier.videoController != null)
              Positioned.fill(
                child: Video(
                  controller: notifier.videoController!,
                  fit: _boxFit(playerState.fitMode),
                  controls: NoVideoControls, // We use our own controls
                ),
              )
            else
              const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE8FF00))),

            // Controls Overlay
            if (playerState.isInitialized)
              AnimatedOpacity(
                opacity: playerState.controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !playerState.controlsVisible,
                  child: PlayerControlsOverlay(
                    playerState: playerState,
                    fileName: widget.fileName,
                    onBack: () => Navigator.pop(context),
                    onTogglePlay: notifier.togglePlay,
                    onCycleFitMode: notifier.cycleFitMode,
                    onShowSpeed: () =>
                        _showSpeedSheet(context, playerState.playbackSpeed),
                    onShowVolume: () =>
                        _showVolumeSheet(context, playerState.volume),
                    onShowAudio: () => _showAudioTrackSheet(context),
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
