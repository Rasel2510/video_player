import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SpeedSheet extends StatefulWidget {
  final double currentSpeed;
  final void Function(double) onSelectSpeed;
  final int currentSeekInterval;
  final void Function(int) onSelectSeekInterval;

  const SpeedSheet({
    super.key,
    required this.currentSpeed,
    required this.onSelectSpeed,
    required this.currentSeekInterval,
    required this.onSelectSeekInterval,
  });

  @override
  State<SpeedSheet> createState() => _SpeedSheetState();
}

class _SpeedSheetState extends State<SpeedSheet> {
  late double _speed;
  static const _seekIntervals = [5, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    _speed = widget.currentSpeed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
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
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PLAYBACK SPEED', style: context.textStyles.label),
              Text(
                '${_speed.toStringAsFixed(2)}×',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              activeTrackColor: context.colors.accent,
              inactiveTrackColor: context.colors.elevated,
              thumbColor: Colors.white,
              overlayColor: context.colors.accent.withAlpha(50),
            ),
            child: Slider(
              value: _speed,
              min: 0.25,
              max: 4.0,
              // 4.0 - 0.25 = 3.75, 3.75 / 0.05 = 75 divisions
              divisions: 75,
              onChanged: (val) {
                setState(() => _speed = val);
                widget.onSelectSpeed(val);
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text('DOUBLE-TAP TO SEEK', style: context.textStyles.label),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _seekIntervals.map((s) {
              final selected = s == widget.currentSeekInterval;
              final label = '${s}s';
              return GestureDetector(
                onTap: () {
                  widget.onSelectSeekInterval(s);
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
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
