import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../providers/player_provider.dart';

/// Bottom sheet to set a sleep timer (auto-pause after a delay or at end of
/// video). Reads/drives the player provider directly and ticks once a second
/// so the remaining time stays live.
class SleepTimerSheet extends ConsumerStatefulWidget {
  const SleepTimerSheet({super.key});

  @override
  ConsumerState<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends ConsumerState<SleepTimerSheet> {
  Timer? _ticker;

  static const _presets = [15, 30, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    // Refresh the "remaining" readout once a second while the sheet is open.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (:endsAt, :endOfVideo) = ref.watch(playerProvider.select((s) => (
          endsAt: s.sleepTimerEndsAt,
          endOfVideo: s.sleepTimerEndOfVideo,
        )));
    final notifier = ref.read(playerProvider.notifier);
    final active = endsAt != null || endOfVideo;

    Duration? remaining;
    if (endsAt != null) {
      final d = endsAt.difference(DateTime.now());
      remaining = d.isNegative ? Duration.zero : d;
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Icon(Icons.bedtime_rounded,
                    color: context.colors.accent, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Sleep timer',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (active)
                  Text(
                    endOfVideo
                        ? 'End of video'
                        : remaining != null
                            ? DurationFormatter.format(remaining)
                            : '',
                    style: TextStyle(
                      color: context.colors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),

          Divider(color: context.colors.divider, height: 1),

          for (final m in _presets)
            _row(
              context,
              label: '$m minutes',
              onTap: () {
                notifier.setSleepTimer(duration: Duration(minutes: m));
                Navigator.pop(context);
              },
            ),
          _row(
            context,
            label: 'End of video',
            icon: Icons.movie_outlined,
            isSelected: endOfVideo,
            onTap: () {
              notifier.setSleepTimer(endOfVideo: true);
              Navigator.pop(context);
            },
          ),
          if (active)
            _row(
              context,
              label: 'Turn off',
              icon: Icons.close_rounded,
              danger: true,
              onTap: () {
                notifier.cancelSleepTimer();
                Navigator.pop(context);
              },
            ),

          SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    IconData icon = Icons.timer_outlined,
    bool isSelected = false,
    bool danger = false,
  }) {
    final color = danger
        ? const Color(0xFFE5534B)
        : (isSelected ? context.colors.accent : context.colors.textSecondary);
    return InkWell(
      onTap: onTap,
      splashColor: context.colors.accentSoft,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: danger
                    ? const Color(0xFFE5534B)
                    : (isSelected
                        ? context.colors.accent
                        : context.colors.textMuted)),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Icon(Icons.check_rounded, color: context.colors.accent, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}
