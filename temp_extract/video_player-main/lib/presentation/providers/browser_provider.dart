import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/folder_contents_entity.dart';
import 'dependency_providers.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class BrowserState {
  final List<String> breadcrumbs;
  final AsyncValue<FolderContentsEntity> contents;

  const BrowserState({
    this.breadcrumbs = const [],
    this.contents = const AsyncValue.loading(),
  });

  String? get currentPath =>
      breadcrumbs.isNotEmpty ? breadcrumbs.last : null;

  bool get hasRoot => breadcrumbs.isNotEmpty;

  BrowserState copyWith({
    List<String>? breadcrumbs,
    AsyncValue<FolderContentsEntity>? contents,
  }) =>
      BrowserState(
        breadcrumbs: breadcrumbs ?? this.breadcrumbs,
        contents: contents ?? this.contents,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class BrowserNotifier extends Notifier<BrowserState> {
  @override
  BrowserState build() => const BrowserState();

  Future<void> pickRoot() async {
    final path = await ref.read(pickDirectoryUseCaseProvider).call();
    if (path == null) return;
    state = BrowserState(breadcrumbs: [path]);
    await _loadDir(path);
  }

  Future<void> navigateTo(String dirPath) async {
    final crumbs = [...state.breadcrumbs, dirPath];
    state = state.copyWith(
      breadcrumbs: crumbs,
      contents: const AsyncValue.loading(),
    );
    await _loadDir(dirPath);
  }

  Future<void> navigateUp() async {
    if (state.breadcrumbs.length <= 1) return;
    final crumbs = state.breadcrumbs.sublist(0, state.breadcrumbs.length - 1);
    state = state.copyWith(
      breadcrumbs: crumbs,
      contents: const AsyncValue.loading(),
    );
    await _loadDir(crumbs.last);
  }

  Future<void> navigateToBreadcrumb(int index) async {
    final crumbs = state.breadcrumbs.sublist(0, index + 1);
    state = state.copyWith(
      breadcrumbs: crumbs,
      contents: const AsyncValue.loading(),
    );
    await _loadDir(crumbs.last);
  }

  Future<void> _loadDir(String path) async {
    try {
      final contents =
          await ref.read(listDirectoryUseCaseProvider).call(path);
      state = state.copyWith(contents: AsyncValue.data(contents));
    } catch (e, st) {
      state = state.copyWith(contents: AsyncValue.error(e, st));
    }
  }

  String dirName(String path) {
    final base = p.basename(path);
    return base.isEmpty ? path : base;
  }
}

final browserProvider = NotifierProvider<BrowserNotifier, BrowserState>(
  BrowserNotifier.new,
);
