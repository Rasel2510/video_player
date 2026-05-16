import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
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

  const PlayerState({
    this.isInitialized = false,
    this.isPlaying = false,
    this.controlsVisible = true,
    this.isFullscreen = false,
    this.isSeeking = false,
    this.seekValue = 0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.fitMode = FitMode.contain,
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
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PlayerNotifier extends Notifier<PlayerState> {
  VideoPlayerController? _controller;
  Timer? _hideTimer;

  @override
  PlayerState build() => const PlayerState();

  VideoPlayerController? get controller => _controller;

  Future<void> init(String filePath) async {
    _controller?.dispose();
    _controller = VideoPlayerController.file(File(filePath));
    await _controller!.initialize();
    _controller!.addListener(_onControllerUpdate);
    await _controller!.setVolume(state.volume);
    await _controller!.setPlaybackSpeed(state.playbackSpeed);
    await _controller!.play();
    await WakelockPlus.enable();
    state = state.copyWith(
      isInitialized: true,
      isPlaying: true,
      duration: _controller!.value.duration,
    );
    _startHideTimer();
  }

  void _onControllerUpdate() {
    if (_controller == null) return;
    final v = _controller!.value;
    state = state.copyWith(
      isPlaying: v.isPlaying,
      position: v.position,
      duration: v.duration,
    );
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
    if (_controller == null) return;
    state.isPlaying ? _controller!.pause() : _controller!.play();
    showControls();
  }

  void seekRelative(int seconds) {
    if (_controller == null) return;
    final newPos = state.position + Duration(seconds: seconds);
    final target = newPos < Duration.zero
        ? Duration.zero
        : (newPos > state.duration ? state.duration : newPos);
    _controller!.seekTo(target);
    showControls();
  }

  void beginSeek(double value) {
    state = state.copyWith(isSeeking: true, seekValue: value);
  }

  void updateSeek(double value) {
    state = state.copyWith(seekValue: value);
  }

  void endSeek(double value) {
    if (_controller == null) return;
    final target = Duration(
      milliseconds: (value * state.duration.inMilliseconds).round(),
    );
    _controller!.seekTo(target);
    state = state.copyWith(isSeeking: false);
    showControls();
  }

  void setVolume(double volume) {
    _controller?.setVolume(volume);
    state = state.copyWith(volume: volume);
  }

  void setSpeed(double speed) {
    _controller?.setPlaybackSpeed(speed);
    state = state.copyWith(playbackSpeed: speed);
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
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller = null;
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
