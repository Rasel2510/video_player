import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SpeedSheet extends StatelessWidget {
  final double currentSpeed;
  final void Function(double) onSelect;

  static const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0];

  const SpeedSheet({
    super.key,
    required this.currentSpeed,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('PLAYBACK SPEED', style: context.textStyles.label),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: speeds.map((s) {
              final selected = s == currentSpeed;
              final label = s == s.roundToDouble()
                  ? '${s.toInt()}×'
                  : '$s×';
              return GestureDetector(
                onTap: () {
                  onSelect(s);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? context.colors.accent : context.colors.elevated,
                    borderRadius: AppRadius.sm,
                    border: Border.all(
                      color: selected ? context.colors.accent : context.colors.border,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : context.colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      fontSize: 13,
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
