import 'dart:io';

void main() {
  final dirs = [
    Directory(
        r'D:\fme\flutter_video_player\flutter_video_player\lib\presentation\widgets\library'),
    Directory(
        r'D:\fme\flutter_video_player\flutter_video_player\lib\presentation\widgets\folder_videos')
  ];

  for (final dir in dirs) {
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync()) {
      if (entity is File && entity.path.endsWith('.dart')) {
        var content = entity.readAsStringSync();

        bool modified = false;

        // Remove bad imports
        content = content.replaceAll(
            RegExp(r"import '\.\./\.\./core/theme/app_theme\.dart';\r?\n"), '');
        content = content.replaceAll(
            RegExp(
                r"import '\.\./\.\./core/utils/duration_formatter\.dart';\r?\n"),
            '');
        content = content.replaceAll(
            RegExp(r"import '\.\./\.\./models/video_folder\.dart';\r?\n"), '');
        content = content.replaceAll(
            RegExp(r"import '\.\./\.\./models/video_file\.dart';\r?\n"), '');
        content = content.replaceAll(
            RegExp(r"import '\.\./thumbnail_widget\.dart';\r?\n"), '');

        // Add correct imports if needed
        if ((content.contains('context.colors') ||
                content.contains('context.textStyles') ||
                content.contains('AppRadius')) &&
            !content.contains("import '../../../core/theme/app_theme.dart';")) {
          content = "import '../../../core/theme/app_theme.dart';\n$content";
          modified = true;
        }

        if (content.contains('DurationFormatter') &&
            !content.contains(
                "import '../../../core/utils/duration_formatter.dart';")) {
          content =
              "import '../../../core/utils/duration_formatter.dart';\n$content";
          modified = true;
        }

        if (content.contains('VideoFolder') &&
            !content.contains("import '../../../models/video_folder.dart';")) {
          content = "import '../../../models/video_folder.dart';\n$content";
          modified = true;
        }

        if (content.contains('VideoFile') &&
            !content.contains("import '../../../models/video_file.dart';")) {
          content = "import '../../../models/video_file.dart';\n$content";
          modified = true;
        }

        if (content.contains('VideoThumbnailWidget') &&
            !content.contains("import '../../thumbnail_widget.dart';")) {
          content = "import '../../thumbnail_widget.dart';\n$content";
          modified = true;
        }

        if (modified) {
          entity.writeAsStringSync(content);
        }
      }
    }
  }
}
