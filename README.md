# Flutter Video Player

A feature-rich, performance-optimised local video player for Android, built with Flutter.

## Features

- 📂 **Library scan** — auto-discovers all video files across internal & SD-card storage
- 🔍 **Search & sort** — filter folders/videos by name, date, size, or duration
- ▶️ **Full-screen player** — built on `media_kit` with hardware-accelerated decoding
- ⏩ **Gesture controls** — swipe to seek, adjust volume & brightness
- 🔒 **Screen lock** — tap-lock overlay to prevent accidental touches
- 🎵 **Audio tracks** — switch between multiple audio streams
- 📝 **Subtitles** — load & toggle subtitle tracks
- 🚀 **Auto-play** — countdown-based auto-advance to next video in folder
- ⏱ **Resume playback** — positions saved per-file with resume FAB in folder view
- 🎨 **Light / Dark theme** — persisted preference via `SharedPreferences`
- 🗂 **Recent files** — quick access to last-watched videos
- 🖼 **Thumbnails** — async thumbnail generation with shimmer placeholder & LRU cache

---

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── app.dart                           # MaterialApp + theme setup
│
├── core/
│   ├── theme/
│   │   └── app_theme.dart             # Colors, text styles, radii, BuildContext extensions
│   └── utils/
│       ├── duration_formatter.dart    # HH:MM:SS formatting helper
│       └── file_size_formatter.dart   # Bytes → KB/MB/GB formatting helper
│
├── models/
│   ├── video_file.dart                # VideoFile data model (path, size, modified…)
│   └── video_folder.dart              # VideoFolder data model (path, videos list…)
│
├── services/
│   ├── folder_scanner.dart            # Isolate-based background file-system scanner
│   ├── thumbnail_service.dart         # Async thumbnail generation + LRU cache
│   ├── position_service.dart          # Per-file playback position persistence
│   ├── duration_cache_service.dart    # Cached video duration lookups
│   ├── recent_files_service.dart      # Recent-files list management
│   ├── player_preferences_service.dart# Sort order + player prefs persistence
│   ├── brightness_service.dart        # System brightness control
│   ├── volume_service.dart            # System volume control
│   └── media_session_service.dart     # Android media session / notification
│
├── presentation/
│   ├── providers/                     # Riverpod state providers
│   │   ├── folders_provider.dart      # Folder scan state (FoldersNotifier)
│   │   ├── player_provider.dart       # Player state (PlayerNotifier / media_kit)
│   │   └── theme_provider.dart        # Light/dark theme toggle
│   │
│   └── widgets/
│       ├── thumbnail_widget.dart      # Async thumbnail with shimmer fallback
│       ├── resume_dialog.dart         # Resume-or-restart dialog
│       │
│       ├── player/                    # Player screen sub-widgets
│       │   ├── lock_overlay.dart      # Screen-lock gesture overlay
│       │   ├── auto_play_countdown.dart # Auto-play next-video countdown
│       │   ├── error_state.dart       # Player error UI
│       │   ├── seek_flash.dart        # Seek-flash HUD (+/- seconds indicator)
│       │   ├── swipe_hud.dart         # Swipe-gesture HUD (volume/brightness)
│       │   ├── player_controls_overlay.dart # Main player controls bar
│       │   ├── speed_sheet.dart       # Playback speed bottom sheet
│       │   ├── audio_track_sheet.dart # Audio track selector sheet
│       │   ├── subtitle_sheet.dart    # Subtitle track selector sheet
│       │   └── volume_sheet.dart      # Volume control sheet
│       │
│       ├── library/                   # Library screen sub-widgets
│       │   ├── library_header.dart    # Count bar + search toggle + rescan button
│       │   ├── folder_card.dart       # Folder row card with resume pill
│       │   ├── resume_pill.dart       # "▶ 12:34" resume badge
│       │   ├── new_badge.dart         # "NEW" badge for unseen folders
│       │   ├── no_results.dart        # Empty search result view
│       │   ├── permission_prompt.dart # Storage permission request screen
│       │   ├── scanning_screen.dart   # Full-screen scanning progress
│       │   ├── empty_library.dart     # No-videos-found screen
│       │   ├── centered_prompt.dart   # Generic centered icon+text+action layout
│       │   └── primary_button.dart    # Accent FilledButton
│       │
│       └── folder_videos/             # Folder-videos screen sub-widgets
│           ├── video_card.dart        # Video row card with thumbnail & progress bar
│           ├── sort_option.dart       # SortOption enum + extension (label/icon)
│           ├── sort_sheet.dart        # Sort-by bottom sheet
│           ├── video_options_sheet.dart # Long-press video options sheet
│           ├── option_row.dart        # Single row inside options sheet
│           ├── format_badge.dart      # "MP4 / MKV" extension badge
│           ├── new_video_badge.dart   # "NEW" badge for unseen videos
│           ├── resume_fab.dart        # Resume FAB with position label
│           └── no_results.dart        # Empty search result view
│
└── screens/                           # Full screens (state + layout wiring only)
    ├── home_screen.dart               # App bar shell (theme toggle, file picker) + LibraryScreen body
    ├── library_screen.dart            # Folder library with scan & search
    ├── folder_videos_screen.dart      # Video list for a specific folder
    └── player_screen.dart             # Full-screen video player
```

---

## Architecture

The app follows a **layered architecture**:

```
UI (screens + widgets)
       ↕
Presentation (Riverpod providers)
       ↕
Services (file system, SharedPreferences, platform channels)
```

- **State management**: [Riverpod](https://riverpod.dev/) (`ConsumerStatefulWidget` for screens, `StateNotifierProvider` for business state)
- **Ephemeral UI state** (animations, HUDs, overlays) uses local `setState` inside widgets
- **Player engine**: [media_kit](https://github.com/media-kit/media-kit) — hardware-accelerated, cross-platform
- **Background work**: Folder scanning runs in a Dart `Isolate` via `compute()`; thumbnails generated off the main thread

---

## Getting Started

```bash
# Install dependencies
flutter pub get

# Run on a connected Android device
flutter run

# Build release APK
flutter build apk --release
```

### Requirements
- Flutter 3.19+
- Android SDK 21+ (Android 5.0 Lollipop minimum)
- A physical or emulated Android device for full file-system access

---

## Dependencies  

| Package | Purpose | 
|---|---|
| `media_kit` | Video playback engine |
| `flutter_riverpod` | State management |
| `permission_handler` | Runtime storage permissions |
| `shared_preferences` | Persisting settings & positions |
| `share_plus` | Share video files |
| `path` / `path_provider` | File path utilities |
| `video_thumbnail` | Thumbnail frame extraction |