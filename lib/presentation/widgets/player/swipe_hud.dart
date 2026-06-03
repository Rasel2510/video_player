import 'package:flutter/material.dart';
import '../../providers/player_provider.dart';

class SwipeHud extends StatelessWidget {
  final SwipeGesture gesture;
  final double value;
  
  const SwipeHud({super.key, required this.gesture, required this.value});

  @override
  Widget build(BuildContext context) {
    final isBrightness = gesture == SwipeGesture.brightness;
    final IconData icon;
    if (isBrightness) {
      icon = value > 0.6
          ? Icons.brightness_high_rounded
          : value > 0.3
              ? Icons.brightness_medium_rounded
              : Icons.brightness_low_rounded;
    } else {
      icon = value > 0.6
          ? Icons.volume_up_rounded
          : value > 0.0
              ? Icons.volume_down_rounded
              : Icons.volume_off_rounded;
    }
    final color =
        isBrightness ? const Color(0xFFFFE066) : const Color(0xFF66AAFF);
    final percent = '${(value * 100).round()}%';

    return Align(
      alignment: isBrightness ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: 44,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            SizedBox(
              width: 4,
              height: 90,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: RotatedBox(
                  quarterTurns: -1,
                  child: LinearProgressIndicator(
                    value: value.clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              percent,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
