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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VOLUME',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
              color: AppColors.accent,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.volume_off,
                  color: AppColors.textMuted, size: 20),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: AppColors.textDim,
                    thumbColor: AppColors.accent,
                    overlayColor: AppColors.accentDim,
                    trackHeight: 4,
                  ),
                  child: Slider(
                    min: 0.0,
                    max: 100.0,
                    value: volume.clamp(0.0, 100.0),
                    onChanged: onChanged,
                  ),
                ),
              ),
              const Icon(Icons.volume_up,
                  color: AppColors.textMuted, size: 20),
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                child: Text(
                  '${volume.round()}%',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [0.0, 25.0, 50.0, 75.0, 100.0].map((v) {
              final active = (volume - v).abs() < 1.0;
              return GestureDetector(
                onTap: () => onChanged(v),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: active ? AppColors.accent : AppColors.textDim,
                    ),
                    color: active ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
                  ),
                  child: Text(
                    '${v.round()}%',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: active ? AppColors.accent : AppColors.textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
