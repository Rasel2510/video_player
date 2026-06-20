// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'player_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$PlayerState {
  bool get isInitialized => throw _privateConstructorUsedError;
  bool get isPlaying => throw _privateConstructorUsedError;
  bool get controlsVisible => throw _privateConstructorUsedError;
  RotationMode get rotationMode => throw _privateConstructorUsedError;
  bool get isSeeking => throw _privateConstructorUsedError;
  double get seekValue => throw _privateConstructorUsedError;
  Duration get position => throw _privateConstructorUsedError;
  Duration get duration => throw _privateConstructorUsedError;
  double get volume => throw _privateConstructorUsedError;
  double get brightness => throw _privateConstructorUsedError;
  double get playbackSpeed => throw _privateConstructorUsedError;
  FitMode get fitMode => throw _privateConstructorUsedError;
  List<AudioTrack> get audioTracks => throw _privateConstructorUsedError;
  AudioTrack? get selectedAudioTrack => throw _privateConstructorUsedError;
  SwipeGesture get swipeGesture => throw _privateConstructorUsedError;
  double get swipeValue => throw _privateConstructorUsedError;
  List<VideoFile> get folderVideos => throw _privateConstructorUsedError;
  int get currentIndex => throw _privateConstructorUsedError;
  List<SubtitleTrack> get subtitleTracks => throw _privateConstructorUsedError;
  SubtitleTrack? get selectedSubtitleTrack =>
      throw _privateConstructorUsedError;
  bool get subtitlesEnabled => throw _privateConstructorUsedError;
  bool get isLocked => throw _privateConstructorUsedError;
  bool get lockIconVisible => throw _privateConstructorUsedError;
  bool get hasError => throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;
  int? get autoPlayCountdown => throw _privateConstructorUsedError;
  double get zoomScale => throw _privateConstructorUsedError;
  LoopMode get loopMode =>
      throw _privateConstructorUsedError; // Sleep timer: wall-clock time at which playback auto-pauses (null = off).
  DateTime? get sleepTimerEndsAt =>
      throw _privateConstructorUsedError; // Sleep timer variant: pause when the current video finishes.
  bool get sleepTimerEndOfVideo =>
      throw _privateConstructorUsedError; // Subtitle sync offset in seconds (+ = subtitles later, − = earlier).
  double get subtitleDelay =>
      throw _privateConstructorUsedError; // True while the user holds to temporarily fast-forward (2× speed).
  bool get holdFastForward =>
      throw _privateConstructorUsedError; // A-B repeat: loop between these two points when both are set.
  Duration? get abRepeatStart => throw _privateConstructorUsedError;
  Duration? get abRepeatEnd => throw _privateConstructorUsedError;

  /// Create a copy of PlayerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlayerStateCopyWith<PlayerState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlayerStateCopyWith<$Res> {
  factory $PlayerStateCopyWith(
          PlayerState value, $Res Function(PlayerState) then) =
      _$PlayerStateCopyWithImpl<$Res, PlayerState>;
  @useResult
  $Res call(
      {bool isInitialized,
      bool isPlaying,
      bool controlsVisible,
      RotationMode rotationMode,
      bool isSeeking,
      double seekValue,
      Duration position,
      Duration duration,
      double volume,
      double brightness,
      double playbackSpeed,
      FitMode fitMode,
      List<AudioTrack> audioTracks,
      AudioTrack? selectedAudioTrack,
      SwipeGesture swipeGesture,
      double swipeValue,
      List<VideoFile> folderVideos,
      int currentIndex,
      List<SubtitleTrack> subtitleTracks,
      SubtitleTrack? selectedSubtitleTrack,
      bool subtitlesEnabled,
      bool isLocked,
      bool lockIconVisible,
      bool hasError,
      String? errorMessage,
      int? autoPlayCountdown,
      double zoomScale,
      LoopMode loopMode,
      DateTime? sleepTimerEndsAt,
      bool sleepTimerEndOfVideo,
      double subtitleDelay,
      bool holdFastForward,
      Duration? abRepeatStart,
      Duration? abRepeatEnd});
}

/// @nodoc
class _$PlayerStateCopyWithImpl<$Res, $Val extends PlayerState>
    implements $PlayerStateCopyWith<$Res> {
  _$PlayerStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlayerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isInitialized = null,
    Object? isPlaying = null,
    Object? controlsVisible = null,
    Object? rotationMode = null,
    Object? isSeeking = null,
    Object? seekValue = null,
    Object? position = null,
    Object? duration = null,
    Object? volume = null,
    Object? brightness = null,
    Object? playbackSpeed = null,
    Object? fitMode = null,
    Object? audioTracks = null,
    Object? selectedAudioTrack = freezed,
    Object? swipeGesture = null,
    Object? swipeValue = null,
    Object? folderVideos = null,
    Object? currentIndex = null,
    Object? subtitleTracks = null,
    Object? selectedSubtitleTrack = freezed,
    Object? subtitlesEnabled = null,
    Object? isLocked = null,
    Object? lockIconVisible = null,
    Object? hasError = null,
    Object? errorMessage = freezed,
    Object? autoPlayCountdown = freezed,
    Object? zoomScale = null,
    Object? loopMode = null,
    Object? sleepTimerEndsAt = freezed,
    Object? sleepTimerEndOfVideo = null,
    Object? subtitleDelay = null,
    Object? holdFastForward = null,
    Object? abRepeatStart = freezed,
    Object? abRepeatEnd = freezed,
  }) {
    return _then(_value.copyWith(
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      isPlaying: null == isPlaying
          ? _value.isPlaying
          : isPlaying // ignore: cast_nullable_to_non_nullable
              as bool,
      controlsVisible: null == controlsVisible
          ? _value.controlsVisible
          : controlsVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      rotationMode: null == rotationMode
          ? _value.rotationMode
          : rotationMode // ignore: cast_nullable_to_non_nullable
              as RotationMode,
      isSeeking: null == isSeeking
          ? _value.isSeeking
          : isSeeking // ignore: cast_nullable_to_non_nullable
              as bool,
      seekValue: null == seekValue
          ? _value.seekValue
          : seekValue // ignore: cast_nullable_to_non_nullable
              as double,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as Duration,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      volume: null == volume
          ? _value.volume
          : volume // ignore: cast_nullable_to_non_nullable
              as double,
      brightness: null == brightness
          ? _value.brightness
          : brightness // ignore: cast_nullable_to_non_nullable
              as double,
      playbackSpeed: null == playbackSpeed
          ? _value.playbackSpeed
          : playbackSpeed // ignore: cast_nullable_to_non_nullable
              as double,
      fitMode: null == fitMode
          ? _value.fitMode
          : fitMode // ignore: cast_nullable_to_non_nullable
              as FitMode,
      audioTracks: null == audioTracks
          ? _value.audioTracks
          : audioTracks // ignore: cast_nullable_to_non_nullable
              as List<AudioTrack>,
      selectedAudioTrack: freezed == selectedAudioTrack
          ? _value.selectedAudioTrack
          : selectedAudioTrack // ignore: cast_nullable_to_non_nullable
              as AudioTrack?,
      swipeGesture: null == swipeGesture
          ? _value.swipeGesture
          : swipeGesture // ignore: cast_nullable_to_non_nullable
              as SwipeGesture,
      swipeValue: null == swipeValue
          ? _value.swipeValue
          : swipeValue // ignore: cast_nullable_to_non_nullable
              as double,
      folderVideos: null == folderVideos
          ? _value.folderVideos
          : folderVideos // ignore: cast_nullable_to_non_nullable
              as List<VideoFile>,
      currentIndex: null == currentIndex
          ? _value.currentIndex
          : currentIndex // ignore: cast_nullable_to_non_nullable
              as int,
      subtitleTracks: null == subtitleTracks
          ? _value.subtitleTracks
          : subtitleTracks // ignore: cast_nullable_to_non_nullable
              as List<SubtitleTrack>,
      selectedSubtitleTrack: freezed == selectedSubtitleTrack
          ? _value.selectedSubtitleTrack
          : selectedSubtitleTrack // ignore: cast_nullable_to_non_nullable
              as SubtitleTrack?,
      subtitlesEnabled: null == subtitlesEnabled
          ? _value.subtitlesEnabled
          : subtitlesEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      isLocked: null == isLocked
          ? _value.isLocked
          : isLocked // ignore: cast_nullable_to_non_nullable
              as bool,
      lockIconVisible: null == lockIconVisible
          ? _value.lockIconVisible
          : lockIconVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      hasError: null == hasError
          ? _value.hasError
          : hasError // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      autoPlayCountdown: freezed == autoPlayCountdown
          ? _value.autoPlayCountdown
          : autoPlayCountdown // ignore: cast_nullable_to_non_nullable
              as int?,
      zoomScale: null == zoomScale
          ? _value.zoomScale
          : zoomScale // ignore: cast_nullable_to_non_nullable
              as double,
      loopMode: null == loopMode
          ? _value.loopMode
          : loopMode // ignore: cast_nullable_to_non_nullable
              as LoopMode,
      sleepTimerEndsAt: freezed == sleepTimerEndsAt
          ? _value.sleepTimerEndsAt
          : sleepTimerEndsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      sleepTimerEndOfVideo: null == sleepTimerEndOfVideo
          ? _value.sleepTimerEndOfVideo
          : sleepTimerEndOfVideo // ignore: cast_nullable_to_non_nullable
              as bool,
      subtitleDelay: null == subtitleDelay
          ? _value.subtitleDelay
          : subtitleDelay // ignore: cast_nullable_to_non_nullable
              as double,
      holdFastForward: null == holdFastForward
          ? _value.holdFastForward
          : holdFastForward // ignore: cast_nullable_to_non_nullable
              as bool,
      abRepeatStart: freezed == abRepeatStart
          ? _value.abRepeatStart
          : abRepeatStart // ignore: cast_nullable_to_non_nullable
              as Duration?,
      abRepeatEnd: freezed == abRepeatEnd
          ? _value.abRepeatEnd
          : abRepeatEnd // ignore: cast_nullable_to_non_nullable
              as Duration?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlayerStateImplCopyWith<$Res>
    implements $PlayerStateCopyWith<$Res> {
  factory _$$PlayerStateImplCopyWith(
          _$PlayerStateImpl value, $Res Function(_$PlayerStateImpl) then) =
      __$$PlayerStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isInitialized,
      bool isPlaying,
      bool controlsVisible,
      RotationMode rotationMode,
      bool isSeeking,
      double seekValue,
      Duration position,
      Duration duration,
      double volume,
      double brightness,
      double playbackSpeed,
      FitMode fitMode,
      List<AudioTrack> audioTracks,
      AudioTrack? selectedAudioTrack,
      SwipeGesture swipeGesture,
      double swipeValue,
      List<VideoFile> folderVideos,
      int currentIndex,
      List<SubtitleTrack> subtitleTracks,
      SubtitleTrack? selectedSubtitleTrack,
      bool subtitlesEnabled,
      bool isLocked,
      bool lockIconVisible,
      bool hasError,
      String? errorMessage,
      int? autoPlayCountdown,
      double zoomScale,
      LoopMode loopMode,
      DateTime? sleepTimerEndsAt,
      bool sleepTimerEndOfVideo,
      double subtitleDelay,
      bool holdFastForward,
      Duration? abRepeatStart,
      Duration? abRepeatEnd});
}

/// @nodoc
class __$$PlayerStateImplCopyWithImpl<$Res>
    extends _$PlayerStateCopyWithImpl<$Res, _$PlayerStateImpl>
    implements _$$PlayerStateImplCopyWith<$Res> {
  __$$PlayerStateImplCopyWithImpl(
      _$PlayerStateImpl _value, $Res Function(_$PlayerStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlayerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isInitialized = null,
    Object? isPlaying = null,
    Object? controlsVisible = null,
    Object? rotationMode = null,
    Object? isSeeking = null,
    Object? seekValue = null,
    Object? position = null,
    Object? duration = null,
    Object? volume = null,
    Object? brightness = null,
    Object? playbackSpeed = null,
    Object? fitMode = null,
    Object? audioTracks = null,
    Object? selectedAudioTrack = freezed,
    Object? swipeGesture = null,
    Object? swipeValue = null,
    Object? folderVideos = null,
    Object? currentIndex = null,
    Object? subtitleTracks = null,
    Object? selectedSubtitleTrack = freezed,
    Object? subtitlesEnabled = null,
    Object? isLocked = null,
    Object? lockIconVisible = null,
    Object? hasError = null,
    Object? errorMessage = freezed,
    Object? autoPlayCountdown = freezed,
    Object? zoomScale = null,
    Object? loopMode = null,
    Object? sleepTimerEndsAt = freezed,
    Object? sleepTimerEndOfVideo = null,
    Object? subtitleDelay = null,
    Object? holdFastForward = null,
    Object? abRepeatStart = freezed,
    Object? abRepeatEnd = freezed,
  }) {
    return _then(_$PlayerStateImpl(
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      isPlaying: null == isPlaying
          ? _value.isPlaying
          : isPlaying // ignore: cast_nullable_to_non_nullable
              as bool,
      controlsVisible: null == controlsVisible
          ? _value.controlsVisible
          : controlsVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      rotationMode: null == rotationMode
          ? _value.rotationMode
          : rotationMode // ignore: cast_nullable_to_non_nullable
              as RotationMode,
      isSeeking: null == isSeeking
          ? _value.isSeeking
          : isSeeking // ignore: cast_nullable_to_non_nullable
              as bool,
      seekValue: null == seekValue
          ? _value.seekValue
          : seekValue // ignore: cast_nullable_to_non_nullable
              as double,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as Duration,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      volume: null == volume
          ? _value.volume
          : volume // ignore: cast_nullable_to_non_nullable
              as double,
      brightness: null == brightness
          ? _value.brightness
          : brightness // ignore: cast_nullable_to_non_nullable
              as double,
      playbackSpeed: null == playbackSpeed
          ? _value.playbackSpeed
          : playbackSpeed // ignore: cast_nullable_to_non_nullable
              as double,
      fitMode: null == fitMode
          ? _value.fitMode
          : fitMode // ignore: cast_nullable_to_non_nullable
              as FitMode,
      audioTracks: null == audioTracks
          ? _value._audioTracks
          : audioTracks // ignore: cast_nullable_to_non_nullable
              as List<AudioTrack>,
      selectedAudioTrack: freezed == selectedAudioTrack
          ? _value.selectedAudioTrack
          : selectedAudioTrack // ignore: cast_nullable_to_non_nullable
              as AudioTrack?,
      swipeGesture: null == swipeGesture
          ? _value.swipeGesture
          : swipeGesture // ignore: cast_nullable_to_non_nullable
              as SwipeGesture,
      swipeValue: null == swipeValue
          ? _value.swipeValue
          : swipeValue // ignore: cast_nullable_to_non_nullable
              as double,
      folderVideos: null == folderVideos
          ? _value._folderVideos
          : folderVideos // ignore: cast_nullable_to_non_nullable
              as List<VideoFile>,
      currentIndex: null == currentIndex
          ? _value.currentIndex
          : currentIndex // ignore: cast_nullable_to_non_nullable
              as int,
      subtitleTracks: null == subtitleTracks
          ? _value._subtitleTracks
          : subtitleTracks // ignore: cast_nullable_to_non_nullable
              as List<SubtitleTrack>,
      selectedSubtitleTrack: freezed == selectedSubtitleTrack
          ? _value.selectedSubtitleTrack
          : selectedSubtitleTrack // ignore: cast_nullable_to_non_nullable
              as SubtitleTrack?,
      subtitlesEnabled: null == subtitlesEnabled
          ? _value.subtitlesEnabled
          : subtitlesEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      isLocked: null == isLocked
          ? _value.isLocked
          : isLocked // ignore: cast_nullable_to_non_nullable
              as bool,
      lockIconVisible: null == lockIconVisible
          ? _value.lockIconVisible
          : lockIconVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      hasError: null == hasError
          ? _value.hasError
          : hasError // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      autoPlayCountdown: freezed == autoPlayCountdown
          ? _value.autoPlayCountdown
          : autoPlayCountdown // ignore: cast_nullable_to_non_nullable
              as int?,
      zoomScale: null == zoomScale
          ? _value.zoomScale
          : zoomScale // ignore: cast_nullable_to_non_nullable
              as double,
      loopMode: null == loopMode
          ? _value.loopMode
          : loopMode // ignore: cast_nullable_to_non_nullable
              as LoopMode,
      sleepTimerEndsAt: freezed == sleepTimerEndsAt
          ? _value.sleepTimerEndsAt
          : sleepTimerEndsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      sleepTimerEndOfVideo: null == sleepTimerEndOfVideo
          ? _value.sleepTimerEndOfVideo
          : sleepTimerEndOfVideo // ignore: cast_nullable_to_non_nullable
              as bool,
      subtitleDelay: null == subtitleDelay
          ? _value.subtitleDelay
          : subtitleDelay // ignore: cast_nullable_to_non_nullable
              as double,
      holdFastForward: null == holdFastForward
          ? _value.holdFastForward
          : holdFastForward // ignore: cast_nullable_to_non_nullable
              as bool,
      abRepeatStart: freezed == abRepeatStart
          ? _value.abRepeatStart
          : abRepeatStart // ignore: cast_nullable_to_non_nullable
              as Duration?,
      abRepeatEnd: freezed == abRepeatEnd
          ? _value.abRepeatEnd
          : abRepeatEnd // ignore: cast_nullable_to_non_nullable
              as Duration?,
    ));
  }
}

/// @nodoc

class _$PlayerStateImpl extends _PlayerState {
  const _$PlayerStateImpl(
      {this.isInitialized = false,
      this.isPlaying = false,
      this.controlsVisible = true,
      this.rotationMode = RotationMode.auto,
      this.isSeeking = false,
      this.seekValue = 0.0,
      this.position = Duration.zero,
      this.duration = Duration.zero,
      this.volume = 100.0,
      this.brightness = 0.5,
      this.playbackSpeed = 1.0,
      this.fitMode = FitMode.contain,
      final List<AudioTrack> audioTracks = const [],
      this.selectedAudioTrack,
      this.swipeGesture = SwipeGesture.none,
      this.swipeValue = 0.0,
      final List<VideoFile> folderVideos = const [],
      this.currentIndex = -1,
      final List<SubtitleTrack> subtitleTracks = const [],
      this.selectedSubtitleTrack,
      this.subtitlesEnabled = true,
      this.isLocked = false,
      this.lockIconVisible = false,
      this.hasError = false,
      this.errorMessage,
      this.autoPlayCountdown,
      this.zoomScale = 1.0,
      this.loopMode = LoopMode.none,
      this.sleepTimerEndsAt,
      this.sleepTimerEndOfVideo = false,
      this.subtitleDelay = 0.0,
      this.holdFastForward = false,
      this.abRepeatStart,
      this.abRepeatEnd})
      : _audioTracks = audioTracks,
        _folderVideos = folderVideos,
        _subtitleTracks = subtitleTracks,
        super._();

  @override
  @JsonKey()
  final bool isInitialized;
  @override
  @JsonKey()
  final bool isPlaying;
  @override
  @JsonKey()
  final bool controlsVisible;
  @override
  @JsonKey()
  final RotationMode rotationMode;
  @override
  @JsonKey()
  final bool isSeeking;
  @override
  @JsonKey()
  final double seekValue;
  @override
  @JsonKey()
  final Duration position;
  @override
  @JsonKey()
  final Duration duration;
  @override
  @JsonKey()
  final double volume;
  @override
  @JsonKey()
  final double brightness;
  @override
  @JsonKey()
  final double playbackSpeed;
  @override
  @JsonKey()
  final FitMode fitMode;
  final List<AudioTrack> _audioTracks;
  @override
  @JsonKey()
  List<AudioTrack> get audioTracks {
    if (_audioTracks is EqualUnmodifiableListView) return _audioTracks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_audioTracks);
  }

  @override
  final AudioTrack? selectedAudioTrack;
  @override
  @JsonKey()
  final SwipeGesture swipeGesture;
  @override
  @JsonKey()
  final double swipeValue;
  final List<VideoFile> _folderVideos;
  @override
  @JsonKey()
  List<VideoFile> get folderVideos {
    if (_folderVideos is EqualUnmodifiableListView) return _folderVideos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_folderVideos);
  }

  @override
  @JsonKey()
  final int currentIndex;
  final List<SubtitleTrack> _subtitleTracks;
  @override
  @JsonKey()
  List<SubtitleTrack> get subtitleTracks {
    if (_subtitleTracks is EqualUnmodifiableListView) return _subtitleTracks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_subtitleTracks);
  }

  @override
  final SubtitleTrack? selectedSubtitleTrack;
  @override
  @JsonKey()
  final bool subtitlesEnabled;
  @override
  @JsonKey()
  final bool isLocked;
  @override
  @JsonKey()
  final bool lockIconVisible;
  @override
  @JsonKey()
  final bool hasError;
  @override
  final String? errorMessage;
  @override
  final int? autoPlayCountdown;
  @override
  @JsonKey()
  final double zoomScale;
  @override
  @JsonKey()
  final LoopMode loopMode;
// Sleep timer: wall-clock time at which playback auto-pauses (null = off).
  @override
  final DateTime? sleepTimerEndsAt;
// Sleep timer variant: pause when the current video finishes.
  @override
  @JsonKey()
  final bool sleepTimerEndOfVideo;
// Subtitle sync offset in seconds (+ = subtitles later, − = earlier).
  @override
  @JsonKey()
  final double subtitleDelay;
// True while the user holds to temporarily fast-forward (2× speed).
  @override
  @JsonKey()
  final bool holdFastForward;
// A-B repeat: loop between these two points when both are set.
  @override
  final Duration? abRepeatStart;
  @override
  final Duration? abRepeatEnd;

  @override
  String toString() {
    return 'PlayerState(isInitialized: $isInitialized, isPlaying: $isPlaying, controlsVisible: $controlsVisible, rotationMode: $rotationMode, isSeeking: $isSeeking, seekValue: $seekValue, position: $position, duration: $duration, volume: $volume, brightness: $brightness, playbackSpeed: $playbackSpeed, fitMode: $fitMode, audioTracks: $audioTracks, selectedAudioTrack: $selectedAudioTrack, swipeGesture: $swipeGesture, swipeValue: $swipeValue, folderVideos: $folderVideos, currentIndex: $currentIndex, subtitleTracks: $subtitleTracks, selectedSubtitleTrack: $selectedSubtitleTrack, subtitlesEnabled: $subtitlesEnabled, isLocked: $isLocked, lockIconVisible: $lockIconVisible, hasError: $hasError, errorMessage: $errorMessage, autoPlayCountdown: $autoPlayCountdown, zoomScale: $zoomScale, loopMode: $loopMode, sleepTimerEndsAt: $sleepTimerEndsAt, sleepTimerEndOfVideo: $sleepTimerEndOfVideo, subtitleDelay: $subtitleDelay, holdFastForward: $holdFastForward, abRepeatStart: $abRepeatStart, abRepeatEnd: $abRepeatEnd)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlayerStateImpl &&
            (identical(other.isInitialized, isInitialized) ||
                other.isInitialized == isInitialized) &&
            (identical(other.isPlaying, isPlaying) ||
                other.isPlaying == isPlaying) &&
            (identical(other.controlsVisible, controlsVisible) ||
                other.controlsVisible == controlsVisible) &&
            (identical(other.rotationMode, rotationMode) ||
                other.rotationMode == rotationMode) &&
            (identical(other.isSeeking, isSeeking) ||
                other.isSeeking == isSeeking) &&
            (identical(other.seekValue, seekValue) ||
                other.seekValue == seekValue) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.volume, volume) || other.volume == volume) &&
            (identical(other.brightness, brightness) ||
                other.brightness == brightness) &&
            (identical(other.playbackSpeed, playbackSpeed) ||
                other.playbackSpeed == playbackSpeed) &&
            (identical(other.fitMode, fitMode) || other.fitMode == fitMode) &&
            const DeepCollectionEquality()
                .equals(other._audioTracks, _audioTracks) &&
            (identical(other.selectedAudioTrack, selectedAudioTrack) ||
                other.selectedAudioTrack == selectedAudioTrack) &&
            (identical(other.swipeGesture, swipeGesture) ||
                other.swipeGesture == swipeGesture) &&
            (identical(other.swipeValue, swipeValue) ||
                other.swipeValue == swipeValue) &&
            const DeepCollectionEquality()
                .equals(other._folderVideos, _folderVideos) &&
            (identical(other.currentIndex, currentIndex) ||
                other.currentIndex == currentIndex) &&
            const DeepCollectionEquality()
                .equals(other._subtitleTracks, _subtitleTracks) &&
            (identical(other.selectedSubtitleTrack, selectedSubtitleTrack) ||
                other.selectedSubtitleTrack == selectedSubtitleTrack) &&
            (identical(other.subtitlesEnabled, subtitlesEnabled) ||
                other.subtitlesEnabled == subtitlesEnabled) &&
            (identical(other.isLocked, isLocked) ||
                other.isLocked == isLocked) &&
            (identical(other.lockIconVisible, lockIconVisible) ||
                other.lockIconVisible == lockIconVisible) &&
            (identical(other.hasError, hasError) ||
                other.hasError == hasError) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.autoPlayCountdown, autoPlayCountdown) ||
                other.autoPlayCountdown == autoPlayCountdown) &&
            (identical(other.zoomScale, zoomScale) ||
                other.zoomScale == zoomScale) &&
            (identical(other.loopMode, loopMode) ||
                other.loopMode == loopMode) &&
            (identical(other.sleepTimerEndsAt, sleepTimerEndsAt) ||
                other.sleepTimerEndsAt == sleepTimerEndsAt) &&
            (identical(other.sleepTimerEndOfVideo, sleepTimerEndOfVideo) ||
                other.sleepTimerEndOfVideo == sleepTimerEndOfVideo) &&
            (identical(other.subtitleDelay, subtitleDelay) ||
                other.subtitleDelay == subtitleDelay) &&
            (identical(other.holdFastForward, holdFastForward) ||
                other.holdFastForward == holdFastForward) &&
            (identical(other.abRepeatStart, abRepeatStart) ||
                other.abRepeatStart == abRepeatStart) &&
            (identical(other.abRepeatEnd, abRepeatEnd) ||
                other.abRepeatEnd == abRepeatEnd));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        isInitialized,
        isPlaying,
        controlsVisible,
        rotationMode,
        isSeeking,
        seekValue,
        position,
        duration,
        volume,
        brightness,
        playbackSpeed,
        fitMode,
        const DeepCollectionEquality().hash(_audioTracks),
        selectedAudioTrack,
        swipeGesture,
        swipeValue,
        const DeepCollectionEquality().hash(_folderVideos),
        currentIndex,
        const DeepCollectionEquality().hash(_subtitleTracks),
        selectedSubtitleTrack,
        subtitlesEnabled,
        isLocked,
        lockIconVisible,
        hasError,
        errorMessage,
        autoPlayCountdown,
        zoomScale,
        loopMode,
        sleepTimerEndsAt,
        sleepTimerEndOfVideo,
        subtitleDelay,
        holdFastForward,
        abRepeatStart,
        abRepeatEnd
      ]);

  /// Create a copy of PlayerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlayerStateImplCopyWith<_$PlayerStateImpl> get copyWith =>
      __$$PlayerStateImplCopyWithImpl<_$PlayerStateImpl>(this, _$identity);
}

abstract class _PlayerState extends PlayerState {
  const factory _PlayerState(
      {final bool isInitialized,
      final bool isPlaying,
      final bool controlsVisible,
      final RotationMode rotationMode,
      final bool isSeeking,
      final double seekValue,
      final Duration position,
      final Duration duration,
      final double volume,
      final double brightness,
      final double playbackSpeed,
      final FitMode fitMode,
      final List<AudioTrack> audioTracks,
      final AudioTrack? selectedAudioTrack,
      final SwipeGesture swipeGesture,
      final double swipeValue,
      final List<VideoFile> folderVideos,
      final int currentIndex,
      final List<SubtitleTrack> subtitleTracks,
      final SubtitleTrack? selectedSubtitleTrack,
      final bool subtitlesEnabled,
      final bool isLocked,
      final bool lockIconVisible,
      final bool hasError,
      final String? errorMessage,
      final int? autoPlayCountdown,
      final double zoomScale,
      final LoopMode loopMode,
      final DateTime? sleepTimerEndsAt,
      final bool sleepTimerEndOfVideo,
      final double subtitleDelay,
      final bool holdFastForward,
      final Duration? abRepeatStart,
      final Duration? abRepeatEnd}) = _$PlayerStateImpl;
  const _PlayerState._() : super._();

  @override
  bool get isInitialized;
  @override
  bool get isPlaying;
  @override
  bool get controlsVisible;
  @override
  RotationMode get rotationMode;
  @override
  bool get isSeeking;
  @override
  double get seekValue;
  @override
  Duration get position;
  @override
  Duration get duration;
  @override
  double get volume;
  @override
  double get brightness;
  @override
  double get playbackSpeed;
  @override
  FitMode get fitMode;
  @override
  List<AudioTrack> get audioTracks;
  @override
  AudioTrack? get selectedAudioTrack;
  @override
  SwipeGesture get swipeGesture;
  @override
  double get swipeValue;
  @override
  List<VideoFile> get folderVideos;
  @override
  int get currentIndex;
  @override
  List<SubtitleTrack> get subtitleTracks;
  @override
  SubtitleTrack? get selectedSubtitleTrack;
  @override
  bool get subtitlesEnabled;
  @override
  bool get isLocked;
  @override
  bool get lockIconVisible;
  @override
  bool get hasError;
  @override
  String? get errorMessage;
  @override
  int? get autoPlayCountdown;
  @override
  double get zoomScale;
  @override
  LoopMode
      get loopMode; // Sleep timer: wall-clock time at which playback auto-pauses (null = off).
  @override
  DateTime?
      get sleepTimerEndsAt; // Sleep timer variant: pause when the current video finishes.
  @override
  bool
      get sleepTimerEndOfVideo; // Subtitle sync offset in seconds (+ = subtitles later, − = earlier).
  @override
  double
      get subtitleDelay; // True while the user holds to temporarily fast-forward (2× speed).
  @override
  bool
      get holdFastForward; // A-B repeat: loop between these two points when both are set.
  @override
  Duration? get abRepeatStart;
  @override
  Duration? get abRepeatEnd;

  /// Create a copy of PlayerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlayerStateImplCopyWith<_$PlayerStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
