import 'package:flutter/material.dart';
import '../../providers/player_provider.dart';

class SwipeHud extends StatelessWidget {
  final SwipeGesture gesture;

  /// Normalised value passed from the provider.
  ///
  /// • Brightness: 0.0 – 1.0  (direct fraction)
  /// • Volume:     0.0 – 1.0  where 0.5 = device 100 %, 1.0 = boost 200 %
  ///               (stored as volume / 200 in the provider)
  final double value;

  const SwipeHud({super.key, required this.gesture, required this.value});

  @override
  Widget build(BuildContext context) {
    final isBrightness = gesture == SwipeGesture.brightness;

    // ── Volume is boost when the normalised value exceeds 0.5 ──────────────
    // swipeValue = volume / 200, so value > 0.5  ⟺  volume > 100 %
    final isBoosted = !isBrightness && value > 0.5;

    // ── Icon ────────────────────────────────────────────────────────────────
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

    // ── Color: orange for boosted volume, yellow for brightness, blue normal ─
    const Color normalColor = Color(0xFF66AAFF);
    const Color boostColor  = Color(0xFFFF8C00);
    const Color brightnessColor = Color(0xFFFFE066);
    final Color color = isBrightness
        ? brightnessColor
        : (isBoosted ? boostColor : normalColor);

    // ── Percentage text ─────────────────────────────────────────────────────
    // Brightness: value is 0–1  → multiply by 100.
    // Volume    : value is volume/200 → multiply by 200 to get real volume %.
    final String percent = isBrightness
        ? '${(value * 100).round()}%'
        : '${(value * 200).round()}%';

    return Align(
      alignment: isBrightness ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: 44,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xB8000000),
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: const Color(0x1AFFFFFF), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            // ── Progress bar ──────────────────────────────────────────────
            // For boost: split bar — blue up to 50 % mark, orange above it.
            // For normal (brightness or non-boosted volume): single colour.
            SizedBox(
              width: 4,
              height: 90,
              child: isBoosted
                  ? _BoostProgressBar(value: value.clamp(0.0, 1.0))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: LinearProgressIndicator(
                          value: value.clamp(0.0, 1.0),
                          backgroundColor: const Color(0x2EFFFFFF),
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

// ─────────────────────────────────────────────────────────────────────────────
// Split bar: blue (normal) region covers 0–50 %, orange (boost) covers 50–100 %
// ─────────────────────────────────────────────────────────────────────────────

class _BoostProgressBar extends StatelessWidget {
  final double value; // 0.0 – 1.0

  const _BoostProgressBar({required this.value});

  @override
  Widget build(BuildContext context) =>
      // RepaintBoundary isolates the custom-painted boost bar into its own
      // layer so surrounding widgets (icon, text) don't trigger its repaint.
      RepaintBoundary(child: CustomPaint(painter: _BoostBarPainter(value: value)));
}

class _BoostBarPainter extends CustomPainter {
  final double value; // 0.0 – 1.0, where 0.5 == device max (100 %)

  const _BoostBarPainter({required this.value});

  static const Color _normalColor = Color(0xFF66AAFF); // blue
  static const Color _boostColor  = Color(0xFFFF8C00); // orange
  static const Color _bgColor     = Color(0x2EFFFFFF); // 18 % white

  @override
  void paint(Canvas canvas, Size size) {
    // Background track
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2)),
      Paint()..color = _bgColor,
    );

    if (value <= 0.0) return;

    // Bar is drawn bottom-up.
    final double filled = size.height * value;
    final double midH   = size.height * 0.5; // the 50 % / device-max mark

    if (value <= 0.5) {
      // Only normal (blue) region is filled.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, size.height - filled, size.width, filled),
          const Radius.circular(2),
        ),
        Paint()..color = _normalColor,
      );
    } else {
      // Full normal (blue) half at the bottom
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, midH, size.width, midH),
          const Radius.circular(2),
        ),
        Paint()..color = _normalColor,
      );
      // Boost (orange) region from midH upward
      final double boostH   = filled - midH;
      final double boostTop = size.height - filled;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, boostTop, size.width, boostH),
          const Radius.circular(2),
        ),
        Paint()..color = _boostColor,
      );
    }
  }

  @override
  bool shouldRepaint(_BoostBarPainter old) => old.value != value;
}
