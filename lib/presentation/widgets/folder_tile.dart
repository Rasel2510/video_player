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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_outlined,
                size: 20, color: AppColors.folderYellow),
            const SizedBox(width: 14),
            Expanded(
              child: Text(name, style: AppTextStyles.body,
                  overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textDim),
          ],
        ),
      ),
    );
  }
}
