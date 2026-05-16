import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class VolumeSheet extends StatefulWidget {
  final double volume;
  final void Function(double) onChanged;

  const VolumeSheet({
    super.key,
    required this.volume,
    required this.onChanged,
  });

  @override
  State<VolumeSheet> createState() => _VolumeSheetState();
}

class _VolumeSheetState extends State<VolumeSheet> {
  late double _vol;

  @override
  void initState() {
    super.initState();
    _vol = widget.volume;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VOLUME', style: AppTextStyles.label),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.volume_off,
                  color: AppColors.textMuted, size: 20),
              Expanded(
                child: Slider(
                  value: _vol,
                  onChanged: (v) {
                    setState(() => _vol = v);
                    widget.onChanged(v);
                  },
                ),
              ),
              const Icon(Icons.volume_up,
                  color: AppColors.textMuted, size: 20),
              const SizedBox(width: 8),
              SizedBox(
                width: 38,
                child: Text(
                  '${(_vol * 100).round()}%',
                  style: AppTextStyles.mono
                      .copyWith(color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [0.0, 0.25, 0.5, 0.75, 1.0].map((v) {
              final active = (_vol - v).abs() < 0.01;
              return GestureDetector(
                onTap: () {
                  setState(() => _vol = v);
                  widget.onChanged(v);
                },
                child: Text(
                  '${(v * 100).round()}%',
                  style: AppTextStyles.mono.copyWith(
                    color:
                        active ? AppColors.accent : AppColors.textMuted,
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
