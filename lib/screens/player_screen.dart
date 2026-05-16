import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum FitMode { contain, cover, fill, natural }

class PlayerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PlayerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _controlsVisible = true;
  bool _isFullscreen = false;
  Timer? _hideTimer;
  FitMode _fitMode = FitMode.contain;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  bool _isSeeking = false;
  double _seekValue = 0;

  static const List<double> _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const List<FitMode> _fitModes = FitMode.values;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    WakelockPlus.enable();
  }

  Future<void> _initPlayer() async {
    _controller = VideoPlayerController.file(File(widget.filePath));
    await _controller.initialize();
    _controller.setVolume(_volume);
    _controller.setPlaybackSpeed(_playbackSpeed);
    _controller.play();
    _controller.addListener(_onVideoUpdate);
    setState(() => _initialized = true);
    _startHideTimer();
  }

  void _onVideoUpdate() { if (mounted) setState(() {}); }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _startHideTimer();
  }

  void _togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
    _showControls();
  }

  void _seekRelative(int seconds) {
    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    final target = pos + Duration(seconds: seconds);
    _controller.seekTo(target < Duration.zero ? Duration.zero : (target > dur ? dur : target));
    _showControls();
  }

  void _setSpeed(double s) {
    setState(() => _playbackSpeed = s);
    _controller.setPlaybackSpeed(s);
    _showControls();
  }

  void _cycleFitMode() {
    final idx = (_fitModes.indexOf(_fitMode) + 1) % _fitModes.length;
    setState(() => _fitMode = _fitModes[idx]);
    _showControls();
  }

  String _fitModeLabel() {
    switch (_fitMode) {
      case FitMode.contain: return 'FIT';
      case FitMode.cover:   return 'CROP';
      case FitMode.fill:    return 'FILL';
      case FitMode.natural: return 'AUTO';
    }
  }

  BoxFit _fitModeToBoxFit() {
    switch (_fitMode) {
      case FitMode.contain: return BoxFit.contain;
      case FitMode.cover:   return BoxFit.cover;
      case FitMode.fill:    return BoxFit.fill;
      case FitMode.natural: return BoxFit.scaleDown;
    }
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _showControls();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _showSpeedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
        side: BorderSide(color: Color(0xFF2A2A2A)),
      ),
      builder: (_) => _SpeedSheet(
        currentSpeed: _playbackSpeed,
        speeds: _speeds,
        onSelect: (s) { Navigator.pop(context); _setSpeed(s); },
      ),
    );
  }

  void _showVolumeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
        side: BorderSide(color: Color(0xFF2A2A2A)),
      ),
      builder: (_) => _VolumeSheet(
        volume: _volume,
        onChanged: (v) => setState(() {
          _volume = v;
          _controller.setVolume(v);
        }),
      ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.removeListener(_onVideoUpdate);
    _controller.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _controlsVisible
            ? () { setState(() => _controlsVisible = false); _hideTimer?.cancel(); }
            : _showControls,
        onDoubleTapDown: (d) {
          final w = MediaQuery.of(context).size.width;
          d.globalPosition.dx < w / 2 ? _seekRelative(-10) : _seekRelative(10);
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: _initialized
                  ? FittedBox(
                      fit: _fitModeToBoxFit(),
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: Color(0xFFE8FF00))),
            ),
            if (_initialized)
              AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: _buildControls(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    final pos = _isSeeking
        ? Duration(milliseconds: (_seekValue * _controller.value.duration.inMilliseconds).round())
        : _controller.value.position;
    final dur = _controller.value.duration;
    final progress = dur.inMilliseconds > 0
        ? (_isSeeking ? _seekValue : pos.inMilliseconds / dur.inMilliseconds)
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent, Colors.transparent, Color(0xDD000000)],
          stops: [0, 0.2, 0.7, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // TOP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.white,
                  ),
                  Expanded(
                    child: Text(widget.fileName,
                        style: const TextStyle(
                          fontSize: 13, color: Colors.white,
                          overflow: TextOverflow.ellipsis, letterSpacing: 0.3,
                        )),
                  ),
                  _Chip(label: _fitModeLabel(), onTap: _cycleFitMode),
                  const SizedBox(width: 8),
                  _Chip(label: '${_playbackSpeed}x', onTap: _showSpeedSheet),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(_volume == 0 ? Icons.volume_off : _volume < 0.5 ? Icons.volume_down : Icons.volume_up, size: 22),
                    onPressed: _showVolumeSheet,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            const Spacer(),
            // CENTER PLAY/PAUSE
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: const Color(0x80000000),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x4DFFFFFF), width: 1.5),
                ),
                child: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 40, color: Colors.white,
                ),
              ),
            ),
            const Spacer(),
            // BOTTOM
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(pos), style: const TextStyle(color: Color(0xFFE8FF00), fontSize: 12, fontFamily: 'monospace')),
                      Text(_fmt(dur), style: const TextStyle(color: Color(0xFF888888), fontSize: 12, fontFamily: 'monospace')),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      trackHeight: 3,
                      thumbColor: const Color(0xFFE8FF00),
                      activeTrackColor: const Color(0xFFE8FF00),
                      inactiveTrackColor: const Color(0xFF333333),
                      overlayColor: const Color(0x33E8FF00),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChangeStart: (_) => setState(() => _isSeeking = true),
                      onChanged: (v) => setState(() => _seekValue = v),
                      onChangeEnd: (v) {
                        _controller.seekTo(Duration(milliseconds: (v * dur.inMilliseconds).round()));
                        setState(() => _isSeeking = false);
                        _showControls();
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        _SeekBtn(label: '−10s', onTap: () => _seekRelative(-10)),
                        const SizedBox(width: 8),
                        _SeekBtn(label: '+10s', onTap: () => _seekRelative(10)),
                      ]),
                      IconButton(
                        icon: Icon(
                          _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                          color: Colors.white, size: 26,
                        ),
                        onPressed: _toggleFullscreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _Chip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFF444444)), color: Colors.black38),
      child: Text(label, style: const TextStyle(color: Color(0xFFE8FF00), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: 'monospace')),
    ),
  );
}

class _SeekBtn extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _SeekBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFF333333)), color: Colors.black45),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace')),
    ),
  );
}

class _SpeedSheet extends StatelessWidget {
  final double currentSpeed;
  final List<double> speeds;
  final void Function(double) onSelect;
  const _SpeedSheet({required this.currentSpeed, required this.speeds, required this.onSelect});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PLAYBACK SPEED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 3, color: Color(0xFFE8FF00), fontFamily: 'monospace')),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: speeds.map((s) {
            final sel = s == currentSpeed;
            return GestureDetector(
              onTap: () => onSelect(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFFE8FF00) : const Color(0xFF1E1E1E),
                  border: Border.all(color: sel ? const Color(0xFFE8FF00) : const Color(0xFF333333)),
                ),
                child: Text('${s}x', style: TextStyle(color: sel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}

class _VolumeSheet extends StatefulWidget {
  final double volume; final void Function(double) onChanged;
  const _VolumeSheet({required this.volume, required this.onChanged});
  @override
  State<_VolumeSheet> createState() => _VolumeSheetState();
}

class _VolumeSheetState extends State<_VolumeSheet> {
  late double _vol;
  @override
  void initState() { super.initState(); _vol = widget.volume; }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('VOLUME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 3, color: Color(0xFFE8FF00), fontFamily: 'monospace')),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.volume_off, color: Color(0xFF555555), size: 20),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbColor: const Color(0xFFE8FF00), activeTrackColor: const Color(0xFFE8FF00),
                inactiveTrackColor: const Color(0xFF333333), overlayColor: const Color(0x33E8FF00), trackHeight: 3,
              ),
              child: Slider(value: _vol, onChanged: (v) { setState(() => _vol = v); widget.onChanged(v); }),
            ),
          ),
          const Icon(Icons.volume_up, color: Color(0xFF555555), size: 20),
          const SizedBox(width: 8),
          SizedBox(width: 38, child: Text('${(_vol * 100).round()}%', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFFE8FF00)))),
        ]),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [0.0, 0.25, 0.5, 0.75, 1.0].map((v) => GestureDetector(
            onTap: () { setState(() => _vol = v); widget.onChanged(v); },
            child: Text('${(v * 100).round()}%', style: TextStyle(color: (_vol - v).abs() < 0.01 ? const Color(0xFFE8FF00) : const Color(0xFF555555), fontSize: 12, fontFamily: 'monospace')),
          )).toList(),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}
