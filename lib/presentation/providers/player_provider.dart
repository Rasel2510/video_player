import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/constants.dart';
import '../../models/video_file.dart';
import '../../services/duration_cache_service.dart';
import '../../services/media_session_service.dart';
import '../../services/position_service.dart';
import '../../services/volume_service.dart';
import '../../services/brightness_service.dart';

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

enum SwipeGesture { none, brightness, volume }

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
  final double brightness;
  final double playbackSpeed;
  final FitMode fitMode;
  final List<AudioTrack> audioTracks;
  final AudioTrack? selectedAudioTrack;
  final SwipeGesture swipeGesture;
  final double swipeValue;
  final List<VideoFile> folderVideos;
  final int currentIndex;
  final List<SubtitleTrack> subtitleTracks;
  final SubtitleTrack? selectedSubtitleTrack;
  final bool subtitlesEnabled;

  const PlayerState({
    this.isInitialized = false,
    this.isPlaying = false,
    this.controlsVisible = true,
    this.isFullscreen = false,
    this.isSeeking = false,
    this.seekValue = 0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100.0,
    this.brightness = 0.5,
    this.playbackSpeed = 1.0,
    this.fitMode = FitMode.contain,
    this.audioTracks = const [],
    this.selectedAudioTrack,
    this.swipeGesture = SwipeGesture.none,
    this.swipeValue = 0,
    this.folderVideos = const [],
    this.currentIndex = -1,
    this.subtitleTracks = const [],
    this.selectedSubtitleTrack,
    this.subtitlesEnabled = true,
  });

  double get progress => duration.inMilliseconds > 0
      ? (isSeeking
          ? seekValue
          : position.inMilliseconds / duration.inMilliseconds)
      : 0.0;

  bool get hasPrevious => currentIndex > 0;
  bool get hasNext =>
      currentIndex >= 0 && currentIndex < folderVideos.length - 1;

  VideoFile? get currentVideo =>
      currentIndex >= 0 && currentIndex < folderVideos.length
          ? folderVideos[currentIndex]
          : null;

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
    double? brightness,
    double? playbackSpeed,
    FitMode? fitMode,
    List<AudioTrack>? audioTracks,
    AudioTrack? selectedAudioTrack,
    SwipeGesture? swipeGesture,
    double? swipeValue,
    List<VideoFile>? folderVideos,
    int? currentIndex,
    List<SubtitleTrack>? subtitleTracks,
    SubtitleTrack? selectedSubtitleTrack,
    bool? subtitlesEnabled,
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
        brightness: brightness ?? this.brightness,
        playbackSpeed: playbackSpeed ?? this.playbackSpeed,
        fitMode: fitMode ?? this.fitMode,
        audioTracks: audioTracks ?? this.audioTracks,
        selectedAudioTrack: selectedAudioTrack ?? this.selectedAudioTrack,
        swipeGesture: swipeGesture ?? this.swipeGesture,
        swipeValue: swipeValue ?? this.swipeValue,
        folderVideos: folderVideos ?? this.folderVideos,
        currentIndex: currentIndex ?? this.currentIndex,
        subtitleTracks: subtitleTracks ?? this.subtitleTracks,
        selectedSubtitleTrack:
            selectedSubtitleTrack ?? this.selectedSubtitleTrack,
        subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PlayerNotifier extends Notifier<PlayerState> {
  Player? _player;
  VideoController? _videoController;
  Timer? _hideTimer;
  Timer? _hudTimer;
  Timer? _saveTimer;
  String? _currentPath;
  double _savedBrightness = 0.5;
  final List<StreamSubscription> _subs = [];

  // Guards against notification panel callbacks after dispose begins.
  bool _isDisposing = false;


  // FIX #14: use shared constant — single source of truth for channel name
  static const _mediaChannel = MethodChannel(AppConstants.mediaSessionChannel);

  @override
  PlayerState build() => const PlayerState();

  Player? get player => _player;
  VideoController? get videoController => _videoController;

  // ── Init ─────────────────────────────────────────────────────────────────────

  Future<void> init(
    String filePath, {
    Duration? resumeFrom,
    List<VideoFile> folderVideos = const [],
    int initialIndex = -1,
  }) async {
    _isDisposing = false;
    // Read device system volume (0.0–1.0), store as 0–100 in state for display.
    final deviceVol = await VolumeService.instance.getDeviceVolume();
    state = PlayerState(
      folderVideos: folderVideos,
      currentIndex: initialIndex,
      volume: deviceVol * 100,
    );

    _disposeInternal();
    _currentPath = filePath;

    _player = Player();
    _videoController = VideoController(_player!);

    // Register handler once. Guards against _isDisposing before touching player.
    _mediaChannel.setMethodCallHandler((call) async {
      // FIX: guard must be the very first thing — the player or its state may
      // already be torn down by the time this callback fires from native.
      if (_isDisposing || _player == null) return;
      try {
        switch (call.method) {
          case 'onMediaAction':
            // FIX: cast safely — a bad argument type must not crash the handler.
            final action = call.arguments as String? ?? '';
            switch (action) {
              case 'play':
              case 'pause':
                togglePlay();
                break;
              case 'next':
                playNext();
                break;
              case 'previous':
                playPrevious();
                break;
            }
            break;
          case 'onMediaSeek':
            final ms = call.arguments as int? ?? 0;
            _player?.seek(Duration(milliseconds: ms));
            break;
        }
      } catch (e) {
        // Swallow any unexpected errors from notification button presses.
        // The player may be in a transient state (loading, buffering, error)
        // that throws internally — this must never propagate to Flutter engine.
      }
    });

    try {
      _savedBrightness = await ScreenBrightness().current;
      final saved = await BrightnessService.instance.getBrightness();
      if (saved != null) {
        state = state.copyWith(brightness: saved);
        await ScreenBrightness().setScreenBrightness(saved);
      } else {
        state = state.copyWith(brightness: _savedBrightness);
      }
    } catch (_) {}

    // Always run media_kit at full internal volume — device volume controls output level.
    await _player!.setVolume(100);
    await _player!.setRate(state.playbackSpeed);

    // Listen for hardware/notification-panel volume changes and keep state in sync.
    VolumeService.instance.addListener((vol) {
      if (!_isDisposing) {
        state = state.copyWith(volume: vol * 100);
      }
    });

    _listenStreams(onReady: () {
      state = state.copyWith(isInitialized: true);
      _startHideTimer();
      if (resumeFrom != null && resumeFrom > Duration.zero) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _player?.seek(resumeFrom);
        });
      }
    });

    await _player!.open(Media(filePath));
    await WakelockPlus.enable();

    await MediaSessionService.setMetadata(
      title: filePath.split('/').last,
      duration: Duration.zero,
    );
  }

  // ── Stream listeners ──────────────────────────────────────────────────────

  void _listenStreams({required VoidCallback onReady}) {
    bool frameReady = false;
    void markReady() {
      if (frameReady) return;
      frameReady = true;
      onReady();
    }

    _subs.add(_player!.stream.playing.listen((v) {
      state = state.copyWith(isPlaying: v);
      _updateLockScreenState();
      if (v) markReady();
    }));

    _subs.add(_player!.stream.position.listen((v) {
      state = state.copyWith(position: v);
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(seconds: 5), _savePosition);
    }));

    _subs.add(_player!.stream.duration.listen((v) {
      if (v <= Duration.zero) return;
      state = state.copyWith(duration: v);
      if (_currentPath != null) {
        DurationCacheService.instance.saveDuration(_currentPath!, v);
      }
      _setLockScreenMetadata();
    }));

    _subs.add(_player!.stream.rate
        .listen((v) => state = state.copyWith(playbackSpeed: v)));

    _subs.add(_player!.stream.tracks.listen((v) {
      final subs =
          v.subtitle.where((t) => t.id != 'no' && t.id != 'auto').toList();
      state = state.copyWith(
        audioTracks: v.audio,
        selectedAudioTrack: _player!.state.track.audio,
        subtitleTracks: subs,
        selectedSubtitleTrack: _player!.state.track.subtitle,
      );
    }));

    _subs.add(_player!.stream.width.listen((w) {
      if (w != null && w > 0) markReady();
    }));

    Future.delayed(const Duration(seconds: 4), markReady);
  }

  // ── Lock screen helpers ───────────────────────────────────────────────────

  void _setLockScreenMetadata() {
    final fileName = _currentPath?.split('/').last ?? '';
    MediaSessionService.setMetadata(
      title: fileName,
      duration: state.duration,
    );
  }

  void _updateLockScreenState() {
    MediaSessionService.setPlaybackState(
      isPlaying: state.isPlaying,
      position: state.position,
      speed: state.playbackSpeed,
    );
  }

  Future<void> _savePosition() async {
    if (_currentPath == null) return;
    await PositionService.instance
        .save(_currentPath!, state.position, state.duration);
  }

  // ── Next / Previous ────────────────────────────────────────────────────────

  Future<void> playNext() async {
    if (!state.hasNext) return;
    final nextIndex = state.currentIndex + 1;
    await _switchVideo(state.folderVideos[nextIndex].path, nextIndex);
  }

  Future<void> playPrevious() async {
    if (!state.hasPrevious) return;
    final prevIndex = state.currentIndex - 1;
    await _switchVideo(state.folderVideos[prevIndex].path, prevIndex);
  }

  Future<void> _switchVideo(String filePath, int index) async {
    await _savePosition();
    _currentPath = filePath;
    state = state.copyWith(
      currentIndex: index,
      isInitialized: false,
      position: Duration.zero,
      duration: Duration.zero,
      isSeeking: false,
    );

    _disposeStreams();

    _player ??= Player();
    _videoController ??= VideoController(_player!);

    _listenStreams(onReady: () {
      state = state.copyWith(isInitialized: true);
      _startHideTimer();
    });

    await _player!.setVolume(100);
    await _player!.open(Media(filePath));

    await MediaSessionService.setMetadata(
      title: filePath.split('/').last,
      duration: Duration.zero,
    );
  }

  // ── Subtitles ──────────────────────────────────────────────────────────────

  void setSubtitleTrack(SubtitleTrack track) {
    _player?.setSubtitleTrack(track);
    state =
        state.copyWith(selectedSubtitleTrack: track, subtitlesEnabled: true);
    showControls();
  }

  void toggleSubtitles() {
    final enabled = !state.subtitlesEnabled;
    if (!enabled) {
      _player?.setSubtitleTrack(SubtitleTrack.no());
    } else if (state.selectedSubtitleTrack != null) {
      _player?.setSubtitleTrack(state.selectedSubtitleTrack!);
    } else if (state.subtitleTracks.isNotEmpty) {
      _player?.setSubtitleTrack(state.subtitleTracks.first);
      state = state.copyWith(selectedSubtitleTrack: state.subtitleTracks.first);
    }
    state = state.copyWith(subtitlesEnabled: enabled);
    showControls();
  }

  // ── Swipe gestures ─────────────────────────────────────────────────────────

  SwipeGesture startSwipe(double dx, double screenWidth) {
    final gesture =
        dx < screenWidth / 2 ? SwipeGesture.brightness : SwipeGesture.volume;
    state = state.copyWith(
      swipeGesture: gesture,
      swipeValue: gesture == SwipeGesture.brightness
          ? state.brightness
          : state.volume / 100.0,
    );
    return gesture;
  }

  void updateSwipe(double dy, double screenHeight) {
    if (state.swipeGesture == SwipeGesture.none) return;
    final delta = -(dy / (screenHeight * 0.6));
    if (state.swipeGesture == SwipeGesture.brightness) {
      final newBrightness = (state.brightness + delta).clamp(0.0, 1.0);
      _applyBrightness(newBrightness);
      state =
          state.copyWith(brightness: newBrightness, swipeValue: newBrightness);
    } else {
      final newVol = ((state.volume / 100.0) + delta).clamp(0.0, 1.0);
      VolumeService.instance.setDeviceVolume(newVol);
      state = state.copyWith(volume: newVol * 100, swipeValue: newVol);
    }
  }

  void endSwipe() {
    final gesture = state.swipeGesture;
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 1500), () {
      state = state.copyWith(swipeGesture: SwipeGesture.none);
    });
    if (gesture == SwipeGesture.brightness) {
      BrightnessService.instance.saveBrightness(state.brightness);
    }
    // Device volume persists on the OS side; no need to save it ourselves.
  }

  Future<void> _applyBrightness(double value) async {
    try {
      await ScreenBrightness().setScreenBrightness(value);
    } catch (_) {}
  }

  // ── Internal cleanup ───────────────────────────────────────────────────────

  void _disposeStreams() {
    _saveTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  void _disposeInternal() {
    _saveTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player?.dispose();
    _player = null;
    _videoController = null;
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (state.isPlaying) state = state.copyWith(controlsVisible: false);
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
    // FIX: guard against calls arriving after dispose() begins (e.g. from the
    // notification panel handler firing just as the player screen is closing).
    if (_isDisposing || _player == null) return;
    try {
      _player?.playOrPause();
    } catch (_) {
      // Swallow — player may be in a transient state (loading/error).
    }
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

  void beginSeek(double value) =>
      state = state.copyWith(isSeeking: true, seekValue: value);

  void updateSeek(double value) => state = state.copyWith(seekValue: value);

  void endSeek(double value) {
    if (_player == null) return;
    final target =
        Duration(milliseconds: (value * state.duration.inMilliseconds).round());
    _player!.seek(target);
    state = state.copyWith(isSeeking: false);
    showControls();
  }

  void setVolume(double volume) {
    // volume is 0–100; convert to 0.0–1.0 for device system volume.
    VolumeService.instance.setDeviceVolume(volume / 100.0);
    state = state.copyWith(volume: volume);
  }

  void setSpeed(double speed) {
    _player?.setRate(speed);
    state = state.copyWith(playbackSpeed: speed);
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

  Future<void> dispose() async {
    // Set flag FIRST — prevents notification callbacks from hitting disposed player.
    _isDisposing = true;

    // Cut the channel handler immediately (sync) so no further native callbacks.
    _mediaChannel.setMethodCallHandler(null);

    // Remove device volume listener.
    VolumeService.instance.removeListener();

    _hideTimer?.cancel();
    _hudTimer?.cancel();

    // Pause immediately so audio stops the instant Back is pressed.
    try {
      await _player?.pause();
    } catch (_) {}

    // FIX #10: Cancel notification FIRST, then save position.
    // Previously release() was called last; the notification could linger
    // for hundreds of ms while position was being written to disk.
    await MediaSessionService.release();

    await _savePosition();
    _disposeInternal();
    state = const PlayerState();

    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (_) {}
    await WakelockPlus.disable();
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
