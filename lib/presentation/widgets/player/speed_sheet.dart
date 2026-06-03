import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SpeedSheet extends StatelessWidget {
  final double currentSpeed;
  final void Function(double) onSelect;

  // FIX #12: Added 1.75× (sweet spot for podcasts/lectures) and 3.0×
  static const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0];

  const SpeedSheet({
    super.key,
    required this.currentSpeed,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  // FIX: call onSelect first — calling pop first can dispose
                  // the BuildContext before setRate() reaches the player.
                  onSelect(s);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? context.colors.accent : context.colors.elevated,
                    // FIX #4: was missing borderRadius — now consistent with rest of app
                    borderRadius: AppRadius.sm,
                    border: Border.all(
                      color: selected ? context.colors.accent : context.colors.border,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.black : context.colors.textPrimary,
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
