import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SpeedSheet extends StatelessWidget {
  final double currentSpeed;
  final void Function(double) onSelect;

  static const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  const SpeedSheet({
    super.key,
    required this.currentSpeed,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PLAYBACK SPEED', style: AppTextStyles.label),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: speeds.map((s) {
              final selected = s == currentSpeed;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onSelect(s);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : AppColors.panel,
                    border: Border.all(
                      color:
                          selected ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  child: Text(
                    '${s}x',
                    style: TextStyle(
                      color: selected ? Colors.black : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
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
