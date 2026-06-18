import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/video_file.dart';
import '../../services/brightness_service.dart';
import '../../services/duration_cache_service.dart';
import '../../services/media_session_service.dart';
import '../../services/player_preferences_service.dart';
import '../../services/position_service.dart';
import '../../services/thumbnail_service.dart';
import '../../services/volume_service.dart';
import '../../core/utils/track_labels.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'player_provider.freezed.dart';

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

enum RotationMode { auto, landscape, portrait }

extension RotationModeX on RotationMode {
  RotationMode get next => switch (this) {
        RotationMode.auto => RotationMode.landscape,
        RotationMode.landscape => RotationMode.portrait,
        RotationMode.portrait => RotationMode.auto,
      };
}

enum SwipeGesture { none, brightness, volume }

// Loop/repeat mode
enum LoopMode { none, loopAll, loopOne }

extension LoopModeX on LoopMode {
  LoopMode get next => LoopMode.values[(index + 1) % LoopMode.values.length];
  bool get isActive => this != LoopMode.none;
}

// ── State ─────────────────────────────────────────────────────────────────────

@freezed
class PlayerState with _$PlayerState {
  const PlayerState._();

  const factory PlayerState({
    @Default(false) bool isInitialized,
    @Default(false) bool isPlaying,
    @Default(true) bool controlsVisible,
    @Default(RotationMode.auto) RotationMode rotationMode,
    @Default(false) bool isSeeking,
    @Default(0.0) double seekValue,
    @Default(Duration.zero) Duration position,
    @Default(Duration.zero) Duration duration,
    @Default(100.0) double volume,
    @Default(0.5) double brightness,
    @Default(1.0) double playbackSpeed,
    @Default(FitMode.contain) FitMode fitMode,
    @Default([]) List<AudioTrack> audioTracks,
    AudioTrack? selectedAudioTrack,
    @Default(SwipeGesture.none) SwipeGesture swipeGesture,
    @Default(0.0) double swipeValue,
    @Default([]) List<VideoFile> folderVideos,
    @Default(-1) int currentIndex,
    @Default([]) List<SubtitleTrack> subtitleTracks,
    SubtitleTrack? selectedSubtitleTrack,
    @Default(true) bool subtitlesEnabled,
    @Default(false) bool isLocked,
    @Default(false) bool lockIconVisible,
    @Default(false) bool hasError,
    String? errorMessage,
    int? autoPlayCountdown,
    @Default(1.0) double zoomScale,
    @Default(LoopMode.none) LoopMode loopMode,
  }) = _PlayerState;

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
  // Resolved thumbnail path for the current video, used as lock-screen art.
  String? _currentArtPath;

  bool _hasStartedPlaying = false;
  final List<StreamSubscription> _subs = [];

  // Externally loaded subtitle files (.srt/.vtt/…). media_kit applies these via
  // SubtitleTrack.uri but does not surface them in the tracks stream, so we keep
  // them here and merge them into the displayed list ourselves.
  final List<SubtitleTrack> _externalSubtitles = [];

  // Single ScreenBrightness instance — avoids creating a new object every call.
  final _brightness = ScreenBrightness();

  // Guards against notification panel callbacks after dispose begins.
  bool _isDisposing = false;

  // Audio (background) mode. When the user taps the audio button we keep the
  // player alive after they leave the screen so playback continues like an
  // audio track, controlled from the lock-screen / notification media session.
  bool _audioMode = false;
  bool get audioMode => _audioMode;

  // Set once the screen has been left (popped) so PopScope + State.dispose —
  // which both fire on exit — don't run the teardown twice.
  bool _leftScreen = false;

  // Throttles lock-screen playback-state syncs to ~1/s — position updates
  // fire several times a second and each sync rebuilds + reposts the
  // Android notification on the native side.
  DateTime? _lastMediaSessionSync;

  // Marks the last time the app itself drove the device volume (swipe / sheet).
  // The OS echoes our change back through the volume listener — quantized to
  // the device's discrete steps — which would otherwise snap the smooth value
  // the user is dragging. We ignore the listener inside this window so only
  // genuine hardware-button presses update state.
  DateTime? _appVolumeChangeAt;

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
    _audioMode = false;
    _leftScreen = false;
    _hasStartedPlaying = false;

    // FIX #OPT-OPEN: Kick off the prefs / device-volume / brightness reads in
    // parallel with opening the file instead of blocking the decode on them.
    // The native decode (the slow part) now overlaps these ~tens of ms of I/O,
    // and the values are applied via copyWith once they resolve.
    final prefsFuture = Future.wait([
      PlayerPreferencesService.instance.loadFitModeIndex(),     // [0]
      PlayerPreferencesService.instance.loadSpeed(),             // [1]
      VolumeService.instance.getDeviceVolume(),                  // [2]
      _brightness.current.catchError((_) => 0.5),               // [3]
      BrightnessService.instance.getBrightness()                 // [4]
          .then<Object?>((v) => v)
          .catchError((_) => null),
      PlayerPreferencesService.instance.loadLoopModeIndex(),     // [5]
    ]);

    _disposeInternal();
    _currentPath = filePath;
    _currentArtPath = null;
    _externalSubtitles.clear();

    // Clean slate for the new video. Prefs (volume/fit/speed/brightness/loop)
    // are merged in via copyWith below — using copyWith rather than a second
    // full PlayerState assignment means an early stream event (e.g. onReady
    // setting isInitialized) isn't clobbered when the prefs land.
    state = PlayerState(folderVideos: folderVideos, currentIndex: initialIndex);

    _player = Player();
    _videoController = VideoController(_player!);

    _listenStreams(onReady: () {
      state = state.copyWith(isInitialized: true);
      _startHideTimer();
      _syncMediaSessionMetadata();
      if (resumeFrom != null && resumeFrom > Duration.zero) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _player?.seek(resumeFrom);
        });
      }
    });

    // Lock-screen / notification controls. setActionHandler overwrites any
    // previous handler so a re-entrant init() doesn't leak handlers.
    MediaSessionService.setActionHandler(
      onAction: _handleMediaAction,
      onSeek: (pos) => _player?.seek(pos),
    );

    // Start decoding immediately — overlaps the prefs reads above and the
    // settings applied below.
    final openFuture = _player!.open(Media(filePath));

    final results = await prefsFuture;
    final fitModeIdx    = results[0] as int;
    final savedSpeed    = results[1] as double;
    final deviceVol     = results[2] as double;
    final currentBri    = results[3] as double;
    final savedBri      = results[4] as double?;
    final loopModeIdx   = results[5] as int;
    final fitMode       = FitMode.values[fitModeIdx.clamp(0, FitMode.values.length - 1)];
    final loopMode      = LoopMode.values[loopModeIdx.clamp(0, LoopMode.values.length - 1)];

    state = state.copyWith(
      volume: deviceVol * 100,
      fitMode: fitMode,
      playbackSpeed: savedSpeed,
      brightness: savedBri ?? currentBri,
      loopMode: loopMode,
    );

    // FIX #OPT-10: removeListener first so that a re-entrant init() (e.g. after
    // an error retry) doesn't silently orphan the previous global slot.
    // FlutterVolumeController only holds one listener at a time; if addListener
    // is called twice the second call overwrites the first without cleanup.
    VolumeService.instance.removeListener();
    VolumeService.instance.addListener((vol) {
      if (_isDisposing) return;
      // Ignore the OS's quantized echo of a volume change we just made — it
      // would snap the smooth value the user is dragging. Only react to real
      // external (hardware-button) changes outside that window.
      final last = _appVolumeChangeAt;
      if (last != null &&
          DateTime.now().difference(last) < const Duration(milliseconds: 600)) {
        return;
      }
      // Only sync device volume changes when not in boost mode.
      // During boost (> 100%), the user explicitly set amplification via the
      // app UI — physical button events should not override that.
      if (state.volume <= 100.0) {
        state = state.copyWith(volume: vol * 100);
      }
    });

    // Apply player + screen settings while the file is already opening.
    await _player!.setVolume(100);
    await _player!.setRate(savedSpeed);
    if (savedBri != null) {
      try { await _brightness.setScreenBrightness(savedBri); } catch (_) {}
    }

    await openFuture;
    WakelockPlus.enable(); // fire-and-forget — never gated the first frame
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
      _syncMediaSessionPlaybackState();
    }));

    _subs.add(_player!.stream.position.listen((v) {
      state = state.copyWith(position: v);
      // Throttled periodic save (3-second debounce).
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(seconds: 3), _savePosition);
      _syncMediaSessionPlaybackState(throttle: true);
    }));

    _subs.add(_player!.stream.duration.listen((v) {
      if (v <= Duration.zero) return;
      state = state.copyWith(duration: v);
      if (_currentPath != null) {
        DurationCacheService.instance.saveDuration(_currentPath!, v);
      }
      _syncMediaSessionMetadata();
    }));

    _subs.add(_player!.stream.rate.listen((v) {
      state = state.copyWith(playbackSpeed: v);
      _syncMediaSessionPlaybackState();
    }));

    _subs.add(_player!.stream.tracks.listen((v) {
      // media_kit injects synthetic 'auto'/'no' placeholder entries alongside
      // the real demuxed tracks — strip them so the UI only ever lists tracks
      // that actually exist in the file. External subtitle files are merged in
      // since they never appear in the demuxed stream.
      final audio =
          v.audio.where((t) => !TrackLabels.isPlaceholderId(t.id)).toList();
      final subs = [
        ...v.subtitle.where((t) => !TrackLabels.isPlaceholderId(t.id)),
        ..._externalSubtitles,
      ];
      state = state.copyWith(
        audioTracks: audio,
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
    // Guard with _isDisposing so we don't call onReady after the player
    // has already been disposed (e.g. user backs out immediately).
    Future.delayed(const Duration(seconds: 4), () {
      if (!_isDisposing) markReady();
    });
  }

  // ── Position save ──────────────────────────────────────────────────────────

  Future<void> _savePosition() async {
    if (_currentPath == null) return;
    await PositionService.instance
        .save(_currentPath!, state.position, state.duration);
  }

  // ── Lock-screen media session ─────────────────────────────────────────────

  void _handleMediaAction(String action) {
    if (_isDisposing || _player == null) return;
    switch (action) {
      case 'play':
        _player!.play();
      case 'pause':
        _player!.pause();
      case 'next':
        playNext();
      case 'previous':
        playPrevious();
    }
  }

  void _syncMediaSessionMetadata() {
    if (_isDisposing) return;
    final path = _currentPath;
    final title = state.currentVideo?.name ??
        (path != null ? p.basename(path) : '');
    // Post immediately with whatever art we've already resolved (may be null),
    // then upgrade once the thumbnail for this video is ready.
    MediaSessionService.setMetadata(
      title: title,
      duration: state.duration,
      artPath: _currentArtPath,
    );
    if (path == null || _currentArtPath != null) return;
    ThumbnailService.instance.getThumbnail(path).then((file) {
      // Bail if we've since disposed or switched to a different video.
      if (_isDisposing || file == null || _currentPath != path) return;
      _currentArtPath = file.path;
      MediaSessionService.setMetadata(
        title: title,
        duration: state.duration,
        artPath: file.path,
      );
    });
  }

  void _syncMediaSessionPlaybackState({bool throttle = false}) {
    if (_isDisposing) return;
    if (throttle) {
      final now = DateTime.now();
      if (_lastMediaSessionSync != null &&
          now.difference(_lastMediaSessionSync!) < const Duration(seconds: 1)) {
        return;
      }
      _lastMediaSessionSync = now;
    }
    MediaSessionService.setPlaybackState(
      isPlaying: state.isPlaying,
      position: state.position,
      speed: state.playbackSpeed,
    );
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
        state = state.copyWith(autoPlayCountdown: null);
        playNext();
      } else {
        state = state.copyWith(autoPlayCountdown: countdown);
      }
    });
  }

  void cancelAutoPlay() {
    _autoPlayTimer?.cancel();
    state = state.copyWith(autoPlayCountdown: null);
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
    _currentArtPath = null;
    _externalSubtitles.clear();
    _hasStartedPlaying = false;

    state = state.copyWith(
      currentIndex: index,
      isInitialized: false,
      position: Duration.zero,
      duration: Duration.zero,
      isSeeking: false,
      autoPlayCountdown: null,
      hasError: false,
      errorMessage: null,
      zoomScale: 1.0, // reset zoom on video switch
    );

    _disposeStreams();

    _player ??= Player();
    _videoController ??= VideoController(_player!);

    _listenStreams(onReady: () {
      state = state.copyWith(isInitialized: true);
      _startHideTimer();
      _syncMediaSessionMetadata();
    });

    // Configure player properties in parallel before opening the file.
    await Future.wait([
      _player!.setVolume(100),
      _player!.setRate(state.playbackSpeed),
      _player!.setPlaylistMode(switch (state.loopMode) {
        LoopMode.none    => PlaylistMode.none,
        LoopMode.loopAll => PlaylistMode.loop,
        LoopMode.loopOne => PlaylistMode.single,
      }),
    ]);
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
    _lockIconTimer = Timer(const Duration(seconds: 2), () {
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

  // ── Loop / repeat ──────────────────────────────────────────────────────────

  void cycleLoopMode() {
    final next = state.loopMode.next;
    state = state.copyWith(loopMode: next);
    PlayerPreferencesService.instance.saveLoopModeIndex(next.index);
    _player?.setPlaylistMode(switch (next) {
      LoopMode.none    => PlaylistMode.none,
      LoopMode.loopAll => PlaylistMode.loop,
      LoopMode.loopOne => PlaylistMode.single,
    });
    showControls();
  }

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

  /// Loads an external subtitle file (.srt/.vtt/.ass/…) from [path], selects it
  /// immediately, and adds it to the subtitle list so the sheet can show and
  /// highlight it. External tracks aren't surfaced by media_kit's tracks stream,
  /// so we track them ourselves (see [_externalSubtitles]).
  Future<void> loadExternalSubtitle(String path) async {
    final player = _player;
    if (player == null) return;
    final track = SubtitleTrack.uri(path, title: p.basename(path));
    try {
      await player.setSubtitleTrack(track);
    } catch (_) {
      return;
    }
    _externalSubtitles
      ..removeWhere((t) => t.id == track.id)
      ..add(track);
    state = state.copyWith(
      subtitleTracks: [
        ...state.subtitleTracks.where((t) => t.id != track.id),
        track,
      ],
      selectedSubtitleTrack: track,
      subtitlesEnabled: true,
    );
    showControls();
  }

  // ── Swipe gestures ─────────────────────────────────────────────────────────

  SwipeGesture startSwipe(double dx, double screenWidth) {
    // Cancel any pending hide-timer left over from a previous gesture so it
    // can't fire mid-swipe and hide the HUD while the finger is still down.
    // (Android's scale recognizer can end+restart during one continuous drag.)
    _hudTimer?.cancel();
    final gesture =
        dx < screenWidth / 2 ? SwipeGesture.brightness : SwipeGesture.volume;
    state = state.copyWith(
      swipeGesture: gesture,
      swipeValue: gesture == SwipeGesture.brightness
          ? state.brightness
          : state.volume / 200.0,
    );
    return gesture;
  }

  void updateSwipe(double dy, double screenHeight) {
    if (state.swipeGesture == SwipeGesture.none) return;
    // Keep the HUD pinned while the finger is actively moving — only endSwipe
    // (finger lift) is allowed to schedule the hide.
    _hudTimer?.cancel();
    final delta = -(dy / (screenHeight * 0.6));
    if (state.swipeGesture == SwipeGesture.brightness) {
      final newBrightness = (state.brightness + delta).clamp(0.0, 1.0);
      _applyBrightness(newBrightness);
      state =
          state.copyWith(brightness: newBrightness, swipeValue: newBrightness);
    } else {
      final newVol = (state.volume + delta * 100).clamp(0.0, 200.0);
      if (newVol <= 100.0) {
        _setDeviceVolume(newVol / 100.0);
        _player?.setVolume(100);
      } else {
        _setDeviceVolume(1.0);
        _player?.setVolume(newVol);
      }
      state = state.copyWith(volume: newVol, swipeValue: newVol / 200.0);
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
    try { await _brightness.setScreenBrightness(value); } catch (_) {}
  }

  // Routes every app-driven device-volume change through one place so the
  // listener can ignore the OS echo (see _appVolumeChangeAt).
  void _setDeviceVolume(double v) {
    _appVolumeChangeAt = DateTime.now();
    VolumeService.instance.setDeviceVolume(v);
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
    _autoPlayTimer?.cancel();
    _lockIconTimer?.cancel();
    _disposeStreams(); // cancels _saveTimer + all stream subs
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
    final clamped = volume.clamp(0.0, 200.0);
    if (clamped <= 100.0) {
      // Normal range: device volume controls output, player at 100% internally.
      _setDeviceVolume(clamped / 100.0);
      _player?.setVolume(100);
    } else {
      // Boost range: device at max, player amplifies beyond 100%.
      _setDeviceVolume(1.0);
      _player?.setVolume(clamped);
    }
    state = state.copyWith(volume: clamped);
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
    state = state.copyWith(fitMode: next, zoomScale: 1.0);
    PlayerPreferencesService.instance.saveFitModeIndex(next.index);
    showControls();
  }

  void cycleRotationMode() {
    final next = state.rotationMode.next;
    state = state.copyWith(rotationMode: next);
    final (orientations, uiMode) = switch (next) {
      RotationMode.landscape => (
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
        SystemUiMode.immersiveSticky,
      ),
      RotationMode.portrait => (
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
        SystemUiMode.immersiveSticky,
      ),
      RotationMode.auto => (
        <DeviceOrientation>[],
        SystemUiMode.edgeToEdge,
      ),
    };
    SystemChrome.setPreferredOrientations(orientations);
    SystemChrome.setEnabledSystemUIMode(uiMode);
    showControls();
  }

  // ── Audio (background) mode ─────────────────────────────────────────────────

  /// Turns the current video into background audio: the player keeps running
  /// after the screen is popped, controlled from the media-session notification.
  /// The caller (PlayerScreen) pops the route right after.
  void enableAudioMode() {
    _audioMode = true;
  }

  /// Called by PlayerScreen when the route is leaving (PopScope + State.dispose
  /// both fire). In audio mode we keep the player alive and only let go of the
  /// on-screen affordances; otherwise we fully tear down.
  Future<void> leaveScreen() async {
    if (_leftScreen) return;
    _leftScreen = true;
    if (_audioMode) {
      await _detachForAudioMode();
    } else {
      await dispose();
    }
  }

  /// Keeps [_player] decoding (audio continues) but restores the system chrome
  /// the player screen had changed, so the screen we return to looks normal.
  /// Streams stay subscribed so position saving, auto-play, and the media
  /// session keep working in the background.
  Future<void> _detachForAudioMode() async {
    _hideTimer?.cancel();
    _lockIconTimer?.cancel();
    _hudTimer?.cancel();
    _saveTimer?.cancel();
    await _savePosition();

    try { await _brightness.resetScreenBrightness(); } catch (_) {}
    // Audio doesn't need the screen awake — let it sleep; playback continues.
    await WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Make sure the notification reflects the latest state now that it's the
    // only control surface.
    _syncMediaSessionMetadata();
    _syncMediaSessionPlaybackState();
  }

  Future<void> dispose() async {
    // PlayerScreen calls this from both PopScope (so orientation/system UI
    // resets before the pop transition) and State.dispose() (safety net for
    // non-pop removal e.g. pushReplacement). Guard so the second call is a
    // no-op instead of redoing every platform-channel reset.
    if (_isDisposing) return;
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
    await MediaSessionService.release();
    _disposeInternal();
    state = const PlayerState();

    try { await _brightness.resetScreenBrightness(); } catch (_) {}
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
