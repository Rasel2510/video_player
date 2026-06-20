import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/player_preferences_service.dart';

/// Preset subtitle text colors. The index into this list is what gets
/// persisted (so adding presets later won't shift anyone's saved choice as
/// long as new colors are appended, not inserted).
const subtitleColorPresets = <Color>[
  Color(0xFFFFFFFF), // White (default)
  Color(0xFFFFEB3B), // Yellow
  Color(0xFF00E5FF), // Cyan
  Color(0xFF76FF03), // Green
];

class SubtitleStyle {
  final double fontSize;
  final int colorIndex;
  final bool background;

  const SubtitleStyle({
    this.fontSize = 32.0,
    this.colorIndex = 0,
    this.background = true,
  });

  Color get color =>
      subtitleColorPresets[colorIndex.clamp(0, subtitleColorPresets.length - 1)];

  SubtitleStyle copyWith({double? fontSize, int? colorIndex, bool? background}) =>
      SubtitleStyle(
        fontSize: fontSize ?? this.fontSize,
        colorIndex: colorIndex ?? this.colorIndex,
        background: background ?? this.background,
      );
}

final subtitleStyleProvider =
    StateNotifierProvider<SubtitleStyleNotifier, SubtitleStyle>((ref) {
  return SubtitleStyleNotifier();
});

class SubtitleStyleNotifier extends StateNotifier<SubtitleStyle> {
  // Seed from the synchronously-cached values (warmed by preload() in main)
  // so the saved style applies on the first frame — no flash of the default.
  SubtitleStyleNotifier() : super(_initial());

  static SubtitleStyle _initial() {
    final prefs = PlayerPreferencesService.instance;
    return SubtitleStyle(
      fontSize: prefs.subtitleFontSizeCached,
      colorIndex: prefs.subtitleColorIndexCached,
      background: prefs.subtitleBackgroundCached,
    );
  }

  static const double minFontSize = 16.0;
  static const double maxFontSize = 56.0;

  void adjustFontSize(double delta) {
    final clamped = (state.fontSize + delta).clamp(minFontSize, maxFontSize);
    state = state.copyWith(fontSize: clamped);
    PlayerPreferencesService.instance.saveSubtitleFontSize(clamped);
  }

  void setColorIndex(int index) {
    state = state.copyWith(colorIndex: index);
    PlayerPreferencesService.instance.saveSubtitleColorIndex(index);
  }

  void setBackground(bool enabled) {
    state = state.copyWith(background: enabled);
    PlayerPreferencesService.instance.saveSubtitleBackground(enabled);
  }
}
