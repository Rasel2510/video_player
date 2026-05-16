import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.border),
          const SizedBox(height: 16),
          Text(title,
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDim)),
          if (actionLabel != null) ...[
            const SizedBox(height: 24),
            _AccentButton(label: actionLabel!, onTap: onAction!),
          ],
        ],
      ),
    );
  }
}

class _AccentButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AccentButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accent),
          ),
          child: Text(label, style: AppTextStyles.label),
        ),
      );
}
