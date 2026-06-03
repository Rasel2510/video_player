import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/video_file.dart';
import '../../services/brightness_service.dart';
import '../../services/duration_cache_service.dart';
import '../../services/player_preferences_service.dart';
import '../../services/position_service.dart';
import '../../services/volume_service.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum FitMode { contain, cover, fill, natural }

extension FitModeX on FitMode {
  String get label => switch (this) {
        FitMode.contain => 'FIT',
        FitMode.cover   => 'CROP',
        FitMode.fill    => 'FILL',
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

  // ── New fields ─────────────────────────────────────────────────────────────
  /// True when the gesture-lock button has been activated.
  final bool isLocked;
  final bool lockIconVisible;

  /// Set to true + errorMessage populated when media_kit reports an error.
  final bool hasError;
  final String? errorMessage;

  /// Non-null when auto-play countdown is running. Counts 5→4→3→2→1 then fires.
  final int? autoPlayCountdown;

  /// Pinch-to-zoom scale factor (1.0 = normal, clamped to 0.5–4.0).
  final double zoomScale;

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
    this.isLocked = false,
    this.lockIconVisible = false,
    this.hasError = false,
    this.errorMessage,
    this.autoPlayCountdown,
    this.zoomScale = 1.0,
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

  VideoFile? get nextVideo =>
      hasNext ? folderVideos[currentIndex + 1] : null;

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
    bool? isLocked,
    bool? lockIconVisible,
    bool? hasError,
    String? errorMessage,
    int? autoPlayCountdown,
    double? zoomScale,
    // Sentinel to allow explicitly nulling autoPlayCountdown
    bool clearAutoPlay = false,
    bool clearError = false,
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
        isLocked: isLocked ?? this.isLocked,
        lockIconVisible: lockIconVisible ?? this.lockIconVisible,
        hasError: clearError ? false : (hasError ?? this.hasError),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        autoPlayCountdown:
            clearAutoPlay ? null : (autoPlayCountdown ?? this.autoPlayCountdown),
        zoomScale: zoomScale ?? this.zoomScale,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PlayerNotifier extends Notifier<PlayerState> {
  Player? _player;
  VideoController? _videoController;
  Timer? _hideTimer;
  Timer? _lockIconTimer;
  Timer? _hudTimer;
  Timer? _saveTimer;
  Timer? _autoPlayTimer;
  String? _currentPath;
  double _savedBrightness = 0.5;
  bool _hasStartedPlaying = false;
  final List<StreamSubscription> _subs = [];

  // Guards against notification panel callbacks after dispose begins.
  bool _isDisposing = false;

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
    _hasStartedPlaying = false;

    // Load persisted preferences.
    final fitModeIdx = await PlayerPreferencesService.instance.loadFitModeIndex();
    final savedSpeed = await PlayerPreferencesService.instance.loadSpeed();
    final fitMode    = FitMode.values[fitModeIdx.clamp(0, FitMode.values.length - 1)];

    // Read device system volume (0.0–1.0), store as 0–100 in state for display.
    final deviceVol = await VolumeService.instance.getDeviceVolume();

    state = PlayerState(
      folderVideos: folderVideos,
      currentIndex: initialIndex,
      volume: deviceVol * 100,
      fitMode: fitMode,
      playbackSpeed: savedSpeed,
    );

    _disposeInternal();
    _currentPath = filePath;

    _player = Player();
    _videoController = VideoController(_player!);

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

    // Always run media_kit at full internal volume — device volume controls output.
    await _player!.setVolume(100);
    await _player!.setRate(savedSpeed);

    VolumeService.instance.addListener((vol) {
      if (!_isDisposing) state = state.copyWith(volume: vol * 100);
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
  }

  // ── Stream listeners ───────────────────────────────────────────────────────

  void _listenStreams({required VoidCallback onReady}) {
    bool frameReady = false;
    void markReady() {
      if (frameReady) return;
      frameReady = true;
      onReady();
    }

    _subs.add(_player!.stream.playing.listen((v) {
      state = state.copyWith(isPlaying: v);
      if (v) {
        markReady();
        _hasStartedPlaying = true;
      } else if (_hasStartedPlaying && !_isDisposing) {
        // Paused by user or end-of-file — persist position immediately.
        _savePosition();
      }
    }));

    _subs.add(_player!.stream.position.listen((v) {
      state = state.copyWith(position: v);
      // Throttled periodic save (5-second debounce).
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(seconds: 5), _savePosition);
    }));

    _subs.add(_player!.stream.duration.listen((v) {
      if (v <= Duration.zero) return;
      state = state.copyWith(duration: v);
      if (_currentPath != null) {
        DurationCacheService.instance.saveDuration(_currentPath!, v);
      }
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

    // Auto-play next video when current one finishes.
    _subs.add(_player!.stream.completed.listen((completed) {
      if (completed && !_isDisposing && state.hasNext) {
        _startAutoPlayCountdown();
      }
    }));

    // Surface any media errors so the UI can show a useful message.
    _subs.add(_player!.stream.error.listen((error) {
      if (!_isDisposing && error.isNotEmpty) {
        state = state.copyWith(
          hasError: true,
          errorMessage: error,
          isInitialized: true, // stop the loading spinner
        );
      }
    }));

    // Safety-net: mark ready after 4 s even if no frame event fires.
    Future.delayed(const Duration(seconds: 4), markReady);
  }

  // ── Position save ──────────────────────────────────────────────────────────

  Future<void> _savePosition() async {
    if (_currentPath == null) return;
    await PositionService.instance
        .save(_currentPath!, state.position, state.duration);
  }

  // ── Auto-play countdown ────────────────────────────────────────────────────

  void _startAutoPlayCountdown() {
    _autoPlayTimer?.cancel();
    int countdown = 5;
    state = state.copyWith(autoPlayCountdown: countdown);

    _autoPlayTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      countdown--;
      if (countdown <= 0) {
        t.cancel();
        state = state.copyWith(clearAutoPlay: true);
        playNext();
      } else {
        state = state.copyWith(autoPlayCountdown: countdown);
      }
    });
  }

  void cancelAutoPlay() {
    _autoPlayTimer?.cancel();
    state = state.copyWith(clearAutoPlay: true);
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
    _autoPlayTimer?.cancel();
    await _savePosition();
    _currentPath = filePath;
    _hasStartedPlaying = false;

    state = state.copyWith(
      currentIndex: index,
      isInitialized: false,
      position: Duration.zero,
      duration: Duration.zero,
      isSeeking: false,
      clearAutoPlay: true,
      clearError: true,
      zoomScale: 1.0, // reset zoom on video switch
    );

    _disposeStreams();

    _player ??= Player();
    _videoController ??= VideoController(_player!);

    _listenStreams(onReady: () {
      state = state.copyWith(isInitialized: true);
      _startHideTimer();
    });

    await _player!.setVolume(100);
    await _player!.setRate(state.playbackSpeed);
    await _player!.open(Media(filePath));
  }

  // ── Gesture lock ──────────────────────────────────────────────────────────

  void toggleLock() {
    final locked = !state.isLocked;
    state = state.copyWith(
      isLocked: locked,
      controlsVisible: !locked,
      lockIconVisible: locked,
    );
    if (locked) {
      _hideTimer?.cancel();
      _startLockIconTimer();
    } else {
      _lockIconTimer?.cancel();
      showControls();
    }
  }

  void _startLockIconTimer() {
    _lockIconTimer?.cancel();
    _lockIconTimer = Timer(const Duration(seconds: 3), () {
      if (state.isLocked && !_isDisposing) {
        state = state.copyWith(lockIconVisible: false);
      }
    });
  }

  void showLockIcon() {
    if (!state.isLocked) return;
    state = state.copyWith(lockIconVisible: true);
    _startLockIconTimer();
  }

  // ── Pinch-to-zoom ─────────────────────────────────────────────────────────

  void setZoomScale(double scale) {
    state = state.copyWith(zoomScale: scale.clamp(0.5, 4.0));
  }

  void resetZoom() => state = state.copyWith(zoomScale: 1.0);

  // ── Subtitles ──────────────────────────────────────────────────────────────

  void setSubtitleTrack(SubtitleTrack track) {
    _player?.setSubtitleTrack(track);
    state = state.copyWith(selectedSubtitleTrack: track, subtitlesEnabled: true);
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
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 1500), () {
      state = state.copyWith(swipeGesture: SwipeGesture.none);
    });
    if (state.swipeGesture == SwipeGesture.brightness) {
      BrightnessService.instance.saveBrightness(state.brightness);
    }
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
    _autoPlayTimer?.cancel();
    _lockIconTimer?.cancel();
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
      if (state.isPlaying && !state.isLocked) {
        state = state.copyWith(controlsVisible: false);
      }
    });
  }

  void showControls() {
    if (state.isLocked) return;
    state = state.copyWith(controlsVisible: true);
    _startHideTimer();
  }

  void hideControls() {
    state = state.copyWith(controlsVisible: false);
    _hideTimer?.cancel();
  }

  void togglePlay() {
    if (_isDisposing || _player == null) return;
    // Cancel auto-play if user interacts manually.
    if (state.autoPlayCountdown != null) cancelAutoPlay();
    try {
      _player?.playOrPause();
    } catch (_) {}
    showControls();
  }

  void seekRelative(int seconds) {
    if (_player == null) return;
    if (state.autoPlayCountdown != null) cancelAutoPlay();
    final newPos = state.position + Duration(seconds: seconds);
    final target = newPos < Duration.zero
        ? Duration.zero
        : (newPos > state.duration ? state.duration : newPos);
    _player!.seek(target);
    showControls();
  }

  void beginSeek(double value) {
    if (state.autoPlayCountdown != null) cancelAutoPlay();
    state = state.copyWith(isSeeking: true, seekValue: value);
  }

  void updateSeek(double value) => state = state.copyWith(seekValue: value);

  void endSeek(double value) {
    if (_player == null) return;
    if (state.autoPlayCountdown != null) cancelAutoPlay();
    final target =
        Duration(milliseconds: (value * state.duration.inMilliseconds).round());
    _player!.seek(target);
    state = state.copyWith(isSeeking: false);
    showControls();
  }

  void setVolume(double volume) {
    VolumeService.instance.setDeviceVolume(volume / 100.0);
    state = state.copyWith(volume: volume);
  }

  void setSpeed(double speed) {
    _player?.setRate(speed);
    state = state.copyWith(playbackSpeed: speed);
    PlayerPreferencesService.instance.saveSpeed(speed);
    showControls();
  }

  void setAudioTrack(AudioTrack track) {
    _player?.setAudioTrack(track);
    state = state.copyWith(selectedAudioTrack: track);
    showControls();
  }

  void cycleFitMode() {
    final next = state.fitMode.next;
    state = state.copyWith(fitMode: next);
    PlayerPreferencesService.instance.saveFitModeIndex(next.index);
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
    _isDisposing = true;
    _autoPlayTimer?.cancel();
    VolumeService.instance.removeListener();
    _hideTimer?.cancel();
    _lockIconTimer?.cancel();
    _hudTimer?.cancel();

    try {
      await _player?.pause();
    } catch (_) {}

    // FIX: cancel the throttle timer BEFORE awaiting _savePosition so it
    // cannot fire concurrently and hit a null _player.
    _saveTimer?.cancel();
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
