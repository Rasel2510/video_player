import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class VolumeSheet extends StatefulWidget {
  final double volume; // 0.0 – 100.0
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
  late double _volume;

  @override
  void initState() {
    super.initState();
    _volume = widget.volume.clamp(0.0, 100.0);
  }

  void _set(double v) {
    setState(() => _volume = v.clamp(0.0, 100.0));
    widget.onChanged(_volume);
  }

  // FIX: preset tap now closes the sheet so UX is consistent with the
  // speed sheet (which closes on tap too). Slider stays open — the user
  // is actively scrubbing and needs to see the value change in real time.
  void _setAndClose(double v) {
    _set(v);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row with Done button ──────────────────────────────────
          Row(
            children: [
              Text('VOLUME', style: context.textStyles.label),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colors.elevated,
                    borderRadius: AppRadius.xl,
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Slider ────────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.volume_off_rounded,
                  color: context.colors.textMuted, size: 20),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: context.colors.accent,
                    inactiveTrackColor: context.colors.textDim,
                    thumbColor: context.colors.accent,
                    overlayColor: context.colors.accentSoft,
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    min: 0.0,
                    max: 100.0,
                    value: _volume,
                    // Slider stays open while dragging — user is actively adjusting.
                    onChanged: _set,
                  ),
                ),
              ),
              Icon(Icons.volume_up_rounded,
                  color: context.colors.textMuted, size: 20),
              const SizedBox(width: 12),
              SizedBox(
                width: 42,
                child: Text(
                  '${_volume.round()}%',
                  style: TextStyle(
                    color: context.colors.accent,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Quick-set presets — closes sheet on tap (consistent UX) ──────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [0.0, 25.0, 50.0, 75.0, 100.0].map((v) {
              final active = (_volume - v).abs() < 1.0;
              return GestureDetector(
                // FIX: close after preset tap — same as SpeedSheet behaviour.
                onTap: () => _setAndClose(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? context.colors.accentSoft : Colors.transparent,
                    border: Border.all(
                      color: active ? context.colors.accent : context.colors.border,
                    ),
                    borderRadius: AppRadius.sm,
                  ),
                  child: Text(
                    '${v.round()}%',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          active ? context.colors.accent : context.colors.textMuted,
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