# Flutter Video Player — Clean Architecture + Riverpod

## Architecture

```
lib/
├── core/
│   ├── theme/
│   │   └── app_theme.dart          # Colors, text styles, ThemeData
│   └── utils/
│       ├── duration_formatter.dart
│       └── file_size_formatter.dart
│
├── data/
│   ├── datasources/
│   │   ├── video_local_datasource.dart   # FilePicker, Directory I/O
│   │   └── recent_local_datasource.dart  # SharedPreferences
│   └── repositories/
│       ├── video_repository_impl.dart
│       └── recent_repository_impl.dart
│
├── domain/
│   ├── entities/
│   │   ├── video_entity.dart
│   │   └── folder_contents_entity.dart
│   ├── repositories/               # Abstract interfaces
│   │   ├── video_repository.dart
│   │   └── recent_repository.dart
│   └── usecases/
│       ├── get_recents_usecase.dart
│       ├── add_recent_usecase.dart
│       ├── remove_recent_usecase.dart
│       ├── clear_recents_usecase.dart
│       ├── pick_video_usecase.dart
│       ├── pick_directory_usecase.dart
│       ├── list_directory_usecase.dart
│       └── scan_directory_usecase.dart
│
└── presentation/
    ├── providers/
    │   ├── dependency_providers.dart   # DI wiring (datasource→repo→usecase)
    │   ├── recents_provider.dart       # AsyncNotifier<List<VideoEntity>>
    │   ├── library_provider.dart       # Notifier<LibraryState>
    │   ├── browser_provider.dart       # Notifier<BrowserState>
    │   └── player_provider.dart        # Notifier<PlayerState>
    ├── screens/                        # Route-level, wire providers → widgets
    │   ├── home_screen.dart
    │   ├── recents_screen.dart
    │   ├── library_screen.dart
    │   ├── browser_screen.dart
    │   └── player_screen.dart
    └── widgets/                        # Pure UI, accept values + callbacks
        ├── video_tile.dart
        ├── recent_tile.dart
        ├── folder_tile.dart
        ├── empty_state.dart
        └── player/
            ├── player_controls_overlay.dart
            ├── speed_sheet.dart
            └── volume_sheet.dart
```

## State Management (Riverpod)

| Provider | Type | Purpose |
|---|---|---|
| `recentsProvider` | `AsyncNotifierProvider` | Persist + load recent files |
| `libraryProvider` | `NotifierProvider` | Folder scan state + search |
| `browserProvider` | `NotifierProvider` | Directory navigation + breadcrumbs |
| `playerProvider` | `NotifierProvider` | VideoPlayerController wrapper |
| `dependency_providers` | `Provider` | DI: datasources → repos → usecases |

## Setup

```bash
flutter pub get

# Generate code (freezed / riverpod_generator - optional, not required here)
# dart run build_runner build

flutter run
```

## Features

- **RECENTS** — Last 20 videos, swipe to delete, tap to replay
- **LIBRARY** — Recursive folder scan with filename search
- **BROWSE** — Directory tree with breadcrumb navigation
- **PLAYER** — Play/Pause, seek bar, ±10s, speed, fit mode, volume, fullscreen
