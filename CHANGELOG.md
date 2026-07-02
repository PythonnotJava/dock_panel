## 0.0.2

- Moved demo application from `lib/main.dart` to `example/` for proper package structure
- Added `DockPanel.copyWith()` method for convenient partial updates
- Added `try-catch` error handling to `_persist()` to prevent crashes on storage failures
- **Enhanced demo:** dark/light theme toggle, `MemoryDockStorage` save/restore, `copyWith()` duplicate-tab demo, interactive file explorer, layout snapshot, panel count in status bar, Welcome panel with feature cards

## 0.0.1

- Initial release
- Drag-and-drop tab docking (left, right, top, bottom, center)
- Resizable split views with hover-highlighted dividers
- Intra-group tab reordering via drag
- Panel maximize / restore
- Animated drop zone indicators and drag feedback
- Themeable via `DockThemeData` (dark and light presets)
- Persistent layout via pluggable `DockStorage` interface
- Riverpod-powered state management (`dockManagerProvider`)
