import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class VolumeSheet extends StatelessWidget {
  final double volume; // 0.0 - 100.0
  final void Function(double) onChanged;

  const VolumeSheet({
    super.key,
    required this.volume,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // FIX #5: Replaced all hardcoded Color(0xFF161616) / Color(0xFF2A2A2A) with
    // AppColors tokens so this sheet respects the theme like every other widget.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VOLUME', style: AppTextStyles.label),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.volume_off_rounded,
                  color: AppColors.textMuted, size: 20),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: AppColors.textDim,
                    thumbColor: AppColors.accent,
                    overlayColor: AppColors.accentSoft,
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    min: 0.0,
                    max: 100.0,
                    value: volume.clamp(0.0, 100.0),
                    onChanged: onChanged,
                  ),
                ),
              ),
              const Icon(Icons.volume_up_rounded,
                  color: AppColors.textMuted, size: 20),
              const SizedBox(width: 12),
              SizedBox(
                width: 42,
                child: Text(
                  '${volume.round()}%',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Quick-set presets
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [0.0, 25.0, 50.0, 75.0, 100.0].map((v) {
              final active = (volume - v).abs() < 1.0;
              return GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    // FIX #5: using AppColors tokens
                    color: active ? AppColors.accentSoft : Colors.transparent,
                    border: Border.all(
                      color: active ? AppColors.accent : AppColors.border,
                    ),
                    borderRadius: AppRadius.sm,
                  ),
                  child: Text(
                    '${v.round()}%',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? AppColors.accent : AppColors.textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
