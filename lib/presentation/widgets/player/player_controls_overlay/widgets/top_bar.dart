part of '../player_controls_overlay.dart';

/// Clean single-row top bar: back + title on the left, screen-orientation and
/// lock on the right. All the feature buttons live in the bottom toolbar now
/// (MX/VLC-style), so the top stays uncluttered and the title has room.
class _TopBar extends ConsumerWidget {
  final String fileName;
  final VoidCallback onBack;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleFullscreen;

  const _TopBar({
    required this.fileName,
    required this.onBack,
    required this.onToggleLock,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rotationMode =
        ref.watch(playerProvider.select((s) => s.rotationMode));

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 0),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 20,
            onTap: onBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _kWhite100,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _GlassIconButton(
            icon: switch (rotationMode) {
              RotationMode.auto => Icons.screen_rotation_rounded,
              RotationMode.landscape => Icons.stay_current_landscape_rounded,
              RotationMode.portrait => Icons.stay_current_portrait_rounded,
            },
            size: 21,
            onTap: onToggleFullscreen,
            active: rotationMode != RotationMode.auto,
          ),
          const SizedBox(width: 2),
          _GlassIconButton(
            icon: Icons.lock_open_rounded,
            size: 20,
            onTap: onToggleLock,
          ),
        ],
      ),
    );
  }
}

// ── Center controls ───────────────────────────────────────────────────────────
