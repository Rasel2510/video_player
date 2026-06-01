import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../core/theme/app_theme.dart';

class FolderTile extends StatelessWidget {
  final String dirPath;
  final VoidCallback onTap;

  const FolderTile({super.key, required this.dirPath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = p.basename(dirPath).isEmpty ? dirPath : p.basename(dirPath);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.md,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.accentSoft,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.folderTint,
                    borderRadius: AppRadius.xs,
                  ),
                  child: const Icon(Icons.folder_rounded,
                      size: 20, color: AppColors.folderIcon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
