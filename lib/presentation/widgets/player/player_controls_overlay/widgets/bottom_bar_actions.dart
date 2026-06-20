part of '../player_controls_overlay.dart';

class _BottomBarActions extends ConsumerWidget {
  final VoidCallback onCycleFitMode;
  final VoidCallback onToggleFullscreen;

  const _BottomBarActions({
    required this.onCycleFitMode,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:fitMode, :rotationMode) = ref.watch(playerProvider.select((s) => (
          fitMode: s.fitMode,
          rotationMode: s.rotationMode,
        )));

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _MiniChip(label: fitMode.label, onTap: onCycleFitMode),
        const SizedBox(width: 12),
        _GlassIconButton(
          icon: switch (rotationMode) {
            RotationMode.auto => Icons.screen_rotation_rounded,
            RotationMode.landscape => Icons.stay_current_landscape_rounded,
            RotationMode.portrait => Icons.stay_current_portrait_rounded,
          },
          size: 24,
          onTap: onToggleFullscreen,
        ),
      ],
    );
  }
}

// ── Custom minimalist slider ──────────────────────────────────────────────────


