# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Qt 6/QML image viewer application for macOS. Features include thumbnail grid view, full-screen image viewing, keyboard navigation, and the ability to move images to trash.

## Build Commands

### Build the app
```bash
# Build in /tmp/build (Release, universal binary)
./build_dmg.sh
```

### Build with code signing
```bash
./build_dmg.sh --sign
```

### Build with code signing and notarization
```bash
./build_dmg.sh --sign --notarize
```

### Manual CMake build
```bash
mkdir build && cd build
cmake .. -DCMAKE_PREFIX_PATH="$HOME/Qt/6.11.0/macos" -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
```

## Architecture

### C++ Layer
- **main.cpp**: Entry point, sets up QML engine, passes initial folder path (if provided via CLI arg), exposes `TrashHandler` to QML
- **trashhandler.h/cpp**: QObject wrapper around `QFile::moveToTrash()` for moving images to trash from QML

### QML Layer
- **ImageViewer.qml**: Main UI with two views:
  - Thumbnail grid using `FolderListModel` from `Qt.labs.folderlistmodel`
  - Full image view with keyboard navigation (arrow keys, Escape, 'd' for trash)

### Key Integration Points
- C++ exposes `trashHandler` and `initialFolder` as context properties to QML
- QML uses `FolderListModel` for scanning image files (png, jpg, jpeg, webp)
- `macdeployqt` bundles Qt frameworks and creates DMG

## Qt Configuration

- Qt version: 6.11.0
- Qt path: `$HOME/Qt/6.11.0/macos` (hardcoded in CMakeLists.txt and build_dmg.sh)
- Required modules: Core, Quick, QuickControls2
- Additional QML imports: `Qt.labs.platform`, `Qt.labs.folderlistmodel`

## Running

```bash
# Run from build directory
./build/ImageViewer.app/Contents/MacOS/ImageViewer

# Open with a specific folder
./build/ImageViewer.app/Contents/MacOS/ImageViewer /path/to/images
```

## Keyboard Shortcuts

- **Arrow keys**: Navigate thumbnails (grid view) or images (full view)
- **Enter/Space**: Open selected image in full view
- **Escape**: Return to thumbnail grid
- **d**: Move current image to trash and load next image