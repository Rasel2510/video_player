import 'package:flutter/material.dart';
import 'package:flutter_video_player/core/theme/app_theme.dart';
import 'sort_option.dart';

class SortSheet extends StatelessWidget {
  final SortOption current;
  final void Function(SortOption) onSelect;

  const SortSheet({super.key, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SORT BY', style: context.textStyles.label),
          const SizedBox(height: 16),
          ...SortOption.values.map((opt) {
            final selected = opt == current;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(opt),
                borderRadius: AppRadius.sm,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  child: Row(
                    children: [
                      Icon(opt.icon,
                          size: 20,
                          color: selected
                              ? context.colors.accent
                              : context.colors.textSecondary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected
                                ? context.colors.accent
                                : context.colors.textPrimary,
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_rounded,
                            size: 18, color: context.colors.accent),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
