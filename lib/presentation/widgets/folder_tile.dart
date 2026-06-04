import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_theme.dart';

class FolderTile extends StatelessWidget {
  final String dirPath;
  final VoidCallback onTap;

  const FolderTile({super.key, required this.dirPath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final base = p.basename(dirPath);
    final name = base.isEmpty ? dirPath : base;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.colors.surface,
        borderRadius: AppRadius.md,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: context.colors.accentSoft,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.colors.folderTint,
                    borderRadius: AppRadius.xs,
                  ),
                  child: Icon(Icons.folder_rounded,
                      size: 20, color: context.colors.folderIcon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: context.colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}