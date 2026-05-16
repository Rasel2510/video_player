import 'package:path/path.dart' as p;
import '../../core/utils/file_size_formatter.dart';

class VideoEntity {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime lastModified;

  const VideoEntity({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.lastModified,
  });

  String get extension => p.extension(name).toLowerCase();
  String get extensionLabel => extension.replaceFirst('.', '').toUpperCase();
  String get sizeLabel => FileSizeFormatter.format(sizeBytes);

  static bool isVideoPath(String filePath) {
    const videoExts = {
      '.mp4', '.mkv', '.mov', '.avi', '.webm',
      '.flv', '.wmv', '.m4v', '.3gp', '.ts', '.m2ts',
    };
    return videoExts.contains(p.extension(filePath).toLowerCase());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VideoEntity && path == other.path;

  @override
  int get hashCode => path.hashCode;

  VideoEntity copyWith({
    String? path,
    String? name,
    int? sizeBytes,
    DateTime? lastModified,
  }) =>
      VideoEntity(
        path: path ?? this.path,
        name: name ?? this.name,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        lastModified: lastModified ?? this.lastModified,
      );
}
