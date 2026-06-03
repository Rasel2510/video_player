import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class VolumeSheet extends StatefulWidget {
  final double volume; // 0.0 – 200.0
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

  // Orange accent used when volume is boosted above 100%.
  static const Color _boostColor = Color(0xFFFF8C00);
  static const Color _boostColorSoft = Color(0x33FF8C00);

  @override
  void initState() {
    super.initState();
    _volume = widget.volume.clamp(0.0, 200.0);
  }

  bool get _isBoosted => _volume > 100.0;

  Color _accent(BuildContext context) =>
      _isBoosted ? _boostColor : context.colors.accent;

  Color _accentSoft(BuildContext context) =>
      _isBoosted ? _boostColorSoft : context.colors.accentSoft;

  void _set(double v) {
    setState(() => _volume = v.clamp(0.0, 200.0));
    widget.onChanged(_volume);
  }

  void _setAndClose(double v) {
    _set(v);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    final accentSoft = _accentSoft(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row with Done button ──────────────────────────────────
          Row(
            children: [
              Text(
                _isBoosted ? 'VOLUME BOOST' : 'VOLUME',
                style: context.textStyles.label.copyWith(
                  color: _isBoosted ? _boostColor : null,
                ),
              ),
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
                    activeTrackColor: accent,
                    inactiveTrackColor: context.colors.textDim,
                    thumbColor: accent,
                    overlayColor: accentSoft,
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    min: 0.0,
                    max: 200.0,
                    value: _volume,
                    onChanged: _set,
                  ),
                ),
              ),
              Icon(Icons.volume_up_rounded,
                  color: context.colors.textMuted, size: 20),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                child: Text(
                  '${_volume.round()}%',
                  style: TextStyle(
                    color: accent,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          // ── Boost indicator bar ───────────────────────────────────────────
          if (_isBoosted)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Row(
                children: [
                  const SizedBox(width: 32),
                  Expanded(
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.colors.accent,
                            _boostColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 68),
                ],
              ),
            )
          else
            const SizedBox(height: 12),

          // ── Quick-set presets — normal range ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [0.0, 25.0, 50.0, 75.0, 100.0].map((v) {
              final active = (_volume - v).abs() < 1.0;
              final isBoostPreset = false;
              return _PresetButton(
                label: '${v.round()}%',
                active: active,
                isBoost: isBoostPreset,
                accent: active ? context.colors.accent : null,
                accentSoft: context.colors.accentSoft,
                border: context.colors.border,
                muted: context.colors.textMuted,
                onTap: () => _setAndClose(v),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // ── Boost presets ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [125.0, 150.0, 175.0, 200.0].map((v) {
              final active = (_volume - v).abs() < 1.0;
              return _PresetButton(
                label: '${v.round()}%',
                active: active,
                isBoost: true,
                accent: active ? _boostColor : null,
                accentSoft: _boostColorSoft,
                border: context.colors.border,
                muted: context.colors.textMuted,
                onTap: () => _setAndClose(v),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final bool active;
  final bool isBoost;
  final Color? accent;
  final Color accentSoft;
  final Color border;
  final Color muted;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.active,
    required this.isBoost,
    required this.accent,
    required this.accentSoft,
    required this.border,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? accentSoft : Colors.transparent,
          border: Border.all(
            color: active
                ? (accent ?? border)
                : isBoost
                    ? const Color(0xFF3A2800)
                    : border,
          ),
          borderRadius: AppRadius.sm,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active
                ? (accent ?? muted)
                : isBoost
                    ? const Color(0xFF8B5E00)
                    : muted,
          ),
        ),
      ),
    );
  }
}
