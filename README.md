# ⚡ ADB Manager & Antigravity Agent Bridge

A lightweight, high-performance **Cross-Platform Desktop Application (Windows & macOS)** and **AI Agent Bridge** built with Flutter to streamline mobile app development.

Eliminates the resource overhead of opening Android Studio solely for its Virtual Device Manager, provides unified controls for running Flutter apps on multiple devices with instant Hot Reload and Hot Restart, features an APK/AppBundle builder, and bridges with Antigravity AI for autonomous auto-hot-reloading as you code.

---

## 🌟 Key Features

- **Cross-Platform Native Desktop**: One unified Dart codebase natively compiled for **Windows** (`.exe`) and **macOS** (`.app`).
- **Standalone AVD Management & Creation**: Create brand new virtual devices (`[+ New AVD]`) directly from installed Android system images, launch emulators in detached high-speed mode, and perform Cold Boot or Wipe Data without opening Android Studio.
- **Option C Multi-Device Workspace**: Tactile inline runner buttons (`[▶ Run]`, `[⚡ Reload]`, `[🔄 Restart]`, `[⏹ Stop]`) on each device card, plus dedicated right-hand tabs with multi-device broadcast controls (`[⚡ Reload All]`, `[🔄 Restart All]`).
- **Antigravity AI Agent Bridge**: Built-in loopback HTTP server (`:45678`) and MCP server that allows Antigravity AI to automatically Hot Reload virtual devices the moment code edits are completed.
- **Dedicated APK & AppBundle Builder**: One-click modal to build Debug, Profile, or Release APKs with ABI splitting, live compilation logs, and instant on-device installation.
- **Full `--dart-define-from-file` Support**: Auto-detects `dart_defines.json` on folder selection and provides quick `[Dev]`, `[Staging]`, and `[Prod]` environment preset switches.
- **One-Click Gradle Lock Cleaner**: Kills hung background Java Gradle daemons (`./gradlew --stop`) and wipes locked intermediate build caches across Windows and macOS.
- **ADB Productivity Suite**: Send PC/Mac clipboard to device, deep link tester, standalone APK sideloading, dark/light theme toggle, screenshot capture, and hardware key injection.
- **Pure Light Mode**: Slate 50 canvas (`#F8FAFC`), pure white container cards (`#FFFFFF`), high-contrast typography (`#0F172A`).

---

## 💻 Platform Support (Windows & macOS)

| Platform | Target Executable | Android SDK Default Path | Tools Detected |
|---|---|---|---|
| **🪟 Windows** | `build\windows\x64\runner\Release\adb_manager.exe` | `%LOCALAPPDATA%\Android\Sdk` | `adb.exe`, `emulator.exe`, `flutter.bat` |
| **🍎 macOS** | `build/macos/Build/Products/Release/adb_manager.app` | `~/Library/Android/sdk` | `adb`, `emulator`, `flutter` (Homebrew/PATH) |

---

## 🚀 Quick Start

### 🪟 On Windows

1. **Launch Directly**:
   - Double-click the **`ADB Manager`** shortcut on your Desktop, or run:
     ```powershell
     & "c:\Users\richa\Documents\devops\ADB Manager\build\windows\x64\runner\Release\adb_manager.exe"
     ```
2. **Run via Flutter**:
   ```powershell
   flutter run -d windows
   ```
3. **Build Release Binary**:
   ```powershell
   flutter build windows --release
   ```

### 🍎 On macOS (OSX)

1. **Clone & Setup**:
   ```bash
   git clone https://github.com/tz86dgrj/adb-manager.git
   cd adb-manager
   ```
2. **Run in Development**:
   ```bash
   flutter run -d macos
   ```
3. **Build Standalone App Bundle**:
   ```bash
   flutter build macos --release
   ```
   The `.app` bundle will be created at:
   ```
   build/macos/Build/Products/Release/adb_manager.app
   ```
   Drag it directly to your `/Applications` directory.

---

## 🤖 Antigravity AI MCP Setup

Add the following to your `~/.gemini/config/mcp_config.json`:

```json
{
  "mcpServers": {
    "adb-manager": {
      "command": "node",
      "args": [
        "<PATH_TO_REPO>/mcp/server.js"
      ],
      "env": {
        "ADB_MANAGER_URL": "http://127.0.0.1:45678"
      }
    }
  }
}
```

---

## 📖 Complete Documentation

For the full architectural breakdown, process communication diagrams, macOS sandboxing details, UI/UX design specifications, and API reference, please see [DOCUMENTATION.md](DOCUMENTATION.md).

---

## 🧪 Testing & Verification

Run the test suite:
```bash
flutter test --no-pub
```

Run static analysis:
```bash
flutter analyze
```
