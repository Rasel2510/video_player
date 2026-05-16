import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/video_folder.dart';
import '../../services/folder_scanner.dart';

class FoldersState {
  final String? rootPath;
  final List<VideoFolder> folders;
  final bool isScanning;
  final int scanProgress;

  const FoldersState({
    this.rootPath,
    this.folders = const [],
    this.isScanning = false,
    this.scanProgress = 0,
  });

  FoldersState copyWith({
    String? rootPath,
    List<VideoFolder>? folders,
    bool? isScanning,
    int? scanProgress,
  }) =>
      FoldersState(
        rootPath: rootPath ?? this.rootPath,
        folders: folders ?? this.folders,
        isScanning: isScanning ?? this.isScanning,
        scanProgress: scanProgress ?? this.scanProgress,
      );
}

class FoldersNotifier extends Notifier<FoldersState> {
  @override
  FoldersState build() => const FoldersState();

  void setRoot(String path) {
    state = state.copyWith(rootPath: path, folders: [], isScanning: true, scanProgress: 0);
    _scan(path);
  }

  Future<void> _scan(String path) async {
    final folders = await FolderScanner.scanFolders(
      path,
      onProgress: (n) {
        state = state.copyWith(scanProgress: n);
      },
    );
    state = state.copyWith(folders: folders, isScanning: false);
  }

  void reset() {
    state = const FoldersState();
  }
}

final foldersProvider = NotifierProvider<FoldersNotifier, FoldersState>(
  FoldersNotifier.new,
);
