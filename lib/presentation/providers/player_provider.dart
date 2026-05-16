import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum FitMode { contain, cover, fill, natural }

extension FitModeX on FitMode {
  String get label => switch (this) {
        FitMode.contain => 'FIT',
        FitMode.cover => 'CROP',
        FitMode.fill => 'FILL',
        FitMode.natural => 'AUTO',
      };

  FitMode get next => FitMode.values[(index + 1) % FitMode.values.length];
}

// ── State ─────────────────────────────────────────────────────────────────────

class PlayerState {
  final bool isInitialized;
  final bool isPlaying;
  final bool controlsVisible;
  final bool isFullscreen;
  final bool isSeeking;
  final double seekValue;
  final Duration position;
  final Duration duration;
  final double volume;
  final double playbackSpeed;
  final FitMode fitMode;
  
  // Multi-audio support
  final List<AudioTrack> audioTracks;
  final AudioTrack? selectedAudioTrack;

  const PlayerState({
    this.isInitialized = false,
    this.isPlaying = false,
    this.controlsVisible = true,
    this.isFullscreen = false,
    this.isSeeking = false,
    this.seekValue = 0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100.0, // media_kit volume is 0-100
    this.playbackSpeed = 1.0,
    this.fitMode = FitMode.contain,
    this.audioTracks = const [],
    this.selectedAudioTrack,
  });

  double get progress => duration.inMilliseconds > 0
      ? (isSeeking
          ? seekValue
          : position.inMilliseconds / duration.inMilliseconds)
      : 0.0;

  PlayerState copyWith({
    bool? isInitialized,
    bool? isPlaying,
    bool? controlsVisible,
    bool? isFullscreen,
    bool? isSeeking,
    double? seekValue,
    Duration? position,
    Duration? duration,
    double? volume,
    double? playbackSpeed,
    FitMode? fitMode,
    List<AudioTrack>? audioTracks,
    AudioTrack? selectedAudioTrack,
  }) =>
      PlayerState(
        isInitialized: isInitialized ?? this.isInitialized,
        isPlaying: isPlaying ?? this.isPlaying,
        controlsVisible: controlsVisible ?? this.controlsVisible,
        isFullscreen: isFullscreen ?? this.isFullscreen,
        isSeeking: isSeeking ?? this.isSeeking,
        seekValue: seekValue ?? this.seekValue,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        volume: volume ?? this.volume,
        playbackSpeed: playbackSpeed ?? this.playbackSpeed,
        fitMode: fitMode ?? this.fitMode,
        audioTracks: audioTracks ?? this.audioTracks,
        selectedAudioTrack: selectedAudioTrack ?? this.selectedAudioTrack,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PlayerNotifier extends Notifier<PlayerState> {
  Player? _player;
  VideoController? _videoController;
  Timer? _hideTimer;
  final List<StreamSubscription> _subs = [];

  @override
  PlayerState build() => const PlayerState();

  Player? get player => _player;
  VideoController? get videoController => _videoController;

  Future<void> init(String filePath) async {
    _disposeInternal();
    
    _player = Player();
    _videoController = VideoController(_player!);

    // Subscriptions
    _subs.add(_player!.stream.playing.listen((v) => state = state.copyWith(isPlaying: v)));
    _subs.add(_player!.stream.position.listen((v) => state = state.copyWith(position: v)));
    _subs.add(_player!.stream.duration.listen((v) => state = state.copyWith(duration: v)));
    _subs.add(_player!.stream.volume.listen((v) => state = state.copyWith(volume: v)));
    _subs.add(_player!.stream.rate.listen((v) => state = state.copyWith(playbackSpeed: v)));
    _subs.add(_player!.stream.tracks.listen((v) {
      state = state.copyWith(
        audioTracks: v.audio,
        selectedAudioTrack: _player!.state.track.audio,
      );
    }));

    await _player!.setVolume(state.volume);
    await _player!.setRate(state.playbackSpeed);
    
    await _player!.open(Media(filePath));
    await WakelockPlus.enable();
    
    state = state.copyWith(isInitialized: true);
    _startHideTimer();
  }

  void _disposeInternal() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player?.dispose();
    _player = null;
    _videoController = null;
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (state.isPlaying) {
        state = state.copyWith(controlsVisible: false);
      }
    });
  }

  void showControls() {
    state = state.copyWith(controlsVisible: true);
    _startHideTimer();
  }

  void hideControls() {
    state = state.copyWith(controlsVisible: false);
    _hideTimer?.cancel();
  }

  void togglePlay() {
    _player?.playOrPause();
    showControls();
  }

  void seekRelative(int seconds) {
    if (_player == null) return;
    final newPos = state.position + Duration(seconds: seconds);
    final target = newPos < Duration.zero
        ? Duration.zero
        : (newPos > state.duration ? state.duration : newPos);
    _player!.seek(target);
    showControls();
  }

  void beginSeek(double value) {
    state = state.copyWith(isSeeking: true, seekValue: value);
  }

  void updateSeek(double value) {
    state = state.copyWith(seekValue: value);
  }

  void endSeek(double value) {
    if (_player == null) return;
    final target = Duration(
      milliseconds: (value * state.duration.inMilliseconds).round(),
    );
    _player!.seek(target);
    state = state.copyWith(isSeeking: false);
    showControls();
  }

  void setVolume(double volume) {
    _player?.setVolume(volume);
    // state is updated via subscription
  }

  void setSpeed(double speed) {
    _player?.setRate(speed);
    // state is updated via subscription
    showControls();
  }

  void setAudioTrack(AudioTrack track) {
    _player?.setAudioTrack(track);
    state = state.copyWith(selectedAudioTrack: track);
    showControls();
  }

  void cycleFitMode() {
    state = state.copyWith(fitMode: state.fitMode.next);
    showControls();
  }

  void toggleFullscreen() {
    final entering = !state.isFullscreen;
    state = state.copyWith(isFullscreen: entering);
    if (entering) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    showControls();
  }

  void dispose() {
    _hideTimer?.cancel();
    _disposeInternal();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);
