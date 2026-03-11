# Recall

A lightweight macOS clipboard manager that runs in your menu bar, tracking clipboard history with powerful keyboard shortcuts and search capabilities.

## Features

- **Unlimited Clipboard History** - Track all your copied text with no artificial limits
- **Smart Search** - Find entries with simple text search or regex patterns
- **Global Hotkeys** - Quick access with Cmd+Shift+V, instant paste with Cmd+1-9/0
- **Pin Items** - Keep important entries at the top
- **Auto-Paste** - Double-click or use shortcuts to paste into any app
- **Lightweight** - Runs in the background with minimal memory footprint
- **Privacy-Focused** - All data stored in memory only, nothing saved to disk

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+V` | Show clipboard panel |
| `Cmd+1` to `Cmd+9` | Paste entries 1-9 |
| `Cmd+0` | Paste 10th entry |
| `Escape` | Close panel |
| `Double-click` | Paste entry and close |

## Requirements

- macOS 12.0 or later
- Accessibility permissions (for global hotkeys and auto-paste)

## Installation

### Build from Source

```bash
cd Recall
./build.sh
open build/Recall.app
```

### Install to Applications

```bash
cp -r build/Recall.app /Applications/
```

## First Launch

1. Run the app - a clipboard icon will appear in your menu bar
2. Grant Accessibility permissions when prompted:
   - System Preferences > Security & Privacy > Privacy > Accessibility
   - Check the box next to Recall
3. Start copying text - it will automatically appear in your history

## Usage

### Basic Usage

1. Copy text normally (`Cmd+C`)
2. Press `Cmd+Shift+V` to view history
3. Double-click any entry to paste it

### Quick Paste (No UI)

Press `Cmd+1` through `Cmd+0` to instantly paste the 1st through 10th most recent items without opening the panel.

### Search

1. Open the panel (`Cmd+Shift+V`)
2. Type in the search box to filter entries
3. Enable "Regex" checkbox for pattern matching

### Pinning

Click the pin icon next to any entry to keep it at the top of the list, even when copying new items.

### Managing History

- Hover over an entry and click the delete button to remove it
- Click "Clear All" to remove all entries
- Re-copying an existing entry moves it to the top and updates its timestamp

## Privacy

- All clipboard data is stored in memory only
- Nothing is saved to disk
- No network access
- No analytics or tracking
- Runs entirely locally on your Mac

## Building from Source

### Prerequisites

Install Xcode Command Line Tools:

```bash
xcode-select --install
```

### Build Script

Run the build script to compile the app:

```bash
./build.sh
```

This creates `build/Recall.app` with:
- Optimized Swift compilation
- Proper code signing
- All required frameworks (AppKit, Carbon)

### Manual Build

If you want to customize the build:

```bash
# Get SDK path
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)

# Create app bundle structure
mkdir -p build/Recall.app/Contents/MacOS
mkdir -p build/Recall.app/Contents/Resources

# Copy resources
cp Sources/Info.plist build/Recall.app/Contents/
cp -r Sources/Assets.xcassets build/Recall.app/Contents/Resources/

# Compile all Swift files
swiftc -sdk "${SDK_PATH}" \
    -target x86_64-apple-macosx12.0 \
    -O -whole-module-optimization \
    -framework AppKit -framework Carbon \
    -o build/Recall.app/Contents/MacOS/Recall \
    Sources/AppDelegate.swift \
    Sources/ClipboardMonitor.swift \
    Sources/ClipboardStore.swift \
    Sources/ClipboardEntry.swift \
    Sources/HotkeyManager.swift \
    Sources/StatusBarController.swift \
    Sources/ClipboardPanel.swift \
    Sources/main.swift

# Make executable
chmod +x build/Recall.app/Contents/MacOS/Recall

# Sign the app
codesign --force --deep --sign - \
    --entitlements Recall.entitlements \
    build/Recall.app
```

### Development Workflow

1. Edit Swift files in `Sources/`
2. Run `./build.sh` to rebuild
3. Test with `open build/Recall.app`

Use any text editor or IDE (VS Code, Sublime, vim, etc.)

## Architecture

- **AppDelegate.swift** - Application lifecycle
- **ClipboardMonitor.swift** - Monitors clipboard via polling
- **ClipboardStore.swift** - In-memory storage with deduplication
- **ClipboardEntry.swift** - Data model for entries
- **HotkeyManager.swift** - Global hotkey registration (Carbon API)
- **StatusBarController.swift** - Menu bar icon and menu
- **ClipboardPanel.swift** - Main UI panel with search and table view

## Troubleshooting

### Hotkey not working

- Verify Accessibility permissions are granted
- Restart the app after granting permissions

### Paste not working

- Ensure Accessibility permissions are granted
- Check that the app has permission to control your computer

## License

MIT License - See LICENSE file for details
