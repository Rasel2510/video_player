import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/theme/app_theme.dart';

class SubtitleSheet extends StatelessWidget {
  final List<SubtitleTrack> tracks;
  final SubtitleTrack? selectedTrack;
  final bool subtitlesEnabled;
  final void Function(SubtitleTrack) onSelect;
  final VoidCallback onToggle;
  final VoidCallback onLoadExternal;
  final double delay; // seconds (+ later, − earlier)
  final void Function(double) onAdjustDelay; // delta seconds
  final VoidCallback onResetDelay;

  const SubtitleSheet({
    super.key,
    required this.tracks,
    required this.selectedTrack,
    required this.subtitlesEnabled,
    required this.onSelect,
    required this.onToggle,
    required this.onLoadExternal,
    required this.delay,
    required this.onAdjustDelay,
    required this.onResetDelay,
  });

  @override
  Widget build(BuildContext context) {
    // isScrollControlled=true is set at the call site so the sheet can grow
    // as needed. Constrain to 75% of screen height so it never covers the video.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.colors.panel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──────────────────────────────────────────────
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

            // ── Header row ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.subtitles_outlined,
                      color: context.colors.accent, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Subtitles',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Global on/off toggle
                  GestureDetector(
                    onTap: () {
                      onToggle();
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: subtitlesEnabled
                            ? context.colors.accentSoft
                            : context.colors.elevated,
                        border: Border.all(
                          color: subtitlesEnabled
                              ? context.colors.accent
                              : context.colors.border,
                        ),
                        borderRadius: AppRadius.sm,
                      ),
                      child: Text(
                        subtitlesEnabled ? 'ON' : 'OFF',
                        style: TextStyle(
                          color: subtitlesEnabled
                              ? context.colors.accent
                              : context.colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: context.colors.divider, height: 1),

            // ── Subtitle sync offset ─────────────────────────────────────
            _DelayControl(
              delay: delay,
              onAdjust: onAdjustDelay,
              onReset: onResetDelay,
            ),

            Divider(color: context.colors.divider, height: 1),

            if (tracks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No subtitle tracks in this file.\nLoad an external .srt file using the button below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              )
            else
              // Track list — scrollable when many tracks
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tracks.length,
                  itemBuilder: (_, i) {
                    final track = tracks[i];
                    final isSelected =
                        subtitlesEnabled && selectedTrack?.id == track.id;
                    final label = track.title?.isNotEmpty == true
                        ? track.title!
                        : track.language?.isNotEmpty == true
                            ? track.language!
                            : 'Track ${i + 1}';

                    return InkWell(
                      onTap: () {
                        onSelect(track);
                        Navigator.pop(context);
                      },
                      splashColor: context.colors.accentSoft,
                      highlightColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? context.colors.accent
                                  : context.colors.textMuted,
                              size: 18,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? context.colors.textPrimary
                                      : context.colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_rounded,
                                  color: context.colors.accent, size: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // ── Load external subtitle button ────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.of(context).padding.bottom),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onLoadExternal();
                  },
                  icon: Icon(Icons.folder_open_outlined,
                      size: 16, color: context.colors.accent),
                  label: Text(
                    'Load external subtitle',
                    style: TextStyle(
                      color: context.colors.accent,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.colors.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.sm),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subtitle delay (+/-) control ────────────────────────────────────────────────

/// Adjusts the subtitle sync offset. Keeps a local copy so the readout updates
/// instantly on tap (the provider is the source of truth for the actual delay).
class _DelayControl extends StatefulWidget {
  final double delay;
  final void Function(double) onAdjust;
  final VoidCallback onReset;

  const _DelayControl({
    required this.delay,
    required this.onAdjust,
    required this.onReset,
  });

  @override
  State<_DelayControl> createState() => _DelayControlState();
}

class _DelayControlState extends State<_DelayControl> {
  late double _delay = widget.delay;
  static const _step = 0.5;

  void _bump(double delta) {
    setState(() => _delay = (_delay + delta).clamp(-60.0, 60.0));
    widget.onAdjust(delta);
  }

  @override
  Widget build(BuildContext context) {
    final label = _delay == 0
        ? '0.0s'
        : '${_delay > 0 ? '+' : ''}${_delay.toStringAsFixed(1)}s';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.av_timer_rounded,
              color: context.colors.textMuted, size: 18),
          const SizedBox(width: 14),
          Text(
            'Sync delay',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
          const Spacer(),
          if (_delay != 0)
            GestureDetector(
              onTap: () {
                setState(() => _delay = 0);
                widget.onReset();
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text('Reset',
                    style: TextStyle(
                        color: context.colors.textMuted, fontSize: 11)),
              ),
            ),
          _StepButton(icon: Icons.remove_rounded, onTap: () => _bump(-_step)),
          SizedBox(
            width: 56,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          _StepButton(icon: Icons.add_rounded, onTap: () => _bump(_step)),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.elevated,
          shape: BoxShape.circle,
          border: Border.all(color: context.colors.border),
        ),
        child: Icon(icon, size: 18, color: context.colors.textSecondary),
      ),
    );
  }
}
