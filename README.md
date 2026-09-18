# ⚡ ADB Manager & Antigravity Agent Bridge

A lightweight, high-performance **Windows Desktop Application** and **AI Agent Bridge** built with Flutter to streamline mobile app development.

Eliminates the resource overhead of opening Android Studio solely for its Virtual Device Manager, provides unified controls for running Flutter apps on multiple devices with instant Hot Reload and Hot Restart, features an APK/AppBundle builder, and bridges with Antigravity AI for autonomous auto-hot-reloading as you code.

---

## 🌟 Key Features

- **Standalone AVD Management**: Launch emulators in high-speed detached mode with Cold Boot and Wipe Data options without opening Android Studio.
- **Option C Multi-Device Workspace**: Tactile inline runner buttons (`[▶ Run]`, `[⚡ Reload]`, `[🔄 Restart]`, `[⏹ Stop]`) on each device card, plus dedicated right-hand tabs with multi-device broadcast controls (`[⚡ Reload All]`, `[🔄 Restart All]`).
- **Antigravity AI Agent Bridge**: Built-in loopback HTTP server (`:45678`) and MCP server that allows Antigravity AI to automatically Hot Reload virtual devices the moment code edits are completed.
- **Dedicated APK & AppBundle Builder**: One-click modal to build Debug, Profile, or Release APKs with ABI splitting, live compilation logs, and instant on-device installation.
- **Full `--dart-define-from-file` Support**: Auto-detects `dart_defines.json` on folder selection and provides quick `[Dev]`, `[Staging]`, and `[Prod]` environment preset switches.
- **One-Click Gradle Lock Cleaner**: Kills hung background Java Gradle daemons (`./gradlew --stop`) and wipes locked intermediate build caches.
- **ADB Productivity Suite**: Send PC clipboard to device, deep link tester, standalone APK sideloading, dark/light theme toggle, screenshot capture, and hardware key injection.
- **Pure Light Mode**: Slate 50 canvas (`#F8FAFC`), pure white container cards (`#FFFFFF`), high-contrast typography (`#0F172A`).

---

## 🚀 Quick Start

### 1. Launch the Application
- Double-click the **`ADB Manager`** shortcut on your Windows Desktop.
- Or run `run.bat` from the repository:
  ```powershell
  & "c:\Users\richa\Documents\devops\ADB Manager\run.bat"
  ```
- Or run the compiled release executable directly:
  ```powershell
  & "c:\Users\richa\Documents\devops\ADB Manager\build\windows\x64\runner\Release\adb_manager.exe"
  ```

### 2. Basic Workflow
1. Select your Flutter project folder using the **Browse...** button in the top bar.
2. In the left panel, click **Start** next to your preferred AVD (e.g. `Pixel_7_Pro`).
3. Once the device finishes booting, click **`[▶ Run App]`** in the hero bar (or on the device card).
4. Use **`F5`** for Hot Reload and **`Shift + F5`** for Hot Restart.

---

## 📖 Complete Documentation

For the full architectural breakdown, process communication diagrams, UI/UX design specifications, and API reference, please see [DOCUMENTATION.md](DOCUMENTATION.md).

---

## 🧪 Testing & Verification

Run the test suite:
```powershell
flutter test
```

Run static analysis:
```powershell
flutter analyze
```

Recompile the release binary:
```powershell
flutter build windows --release
```
