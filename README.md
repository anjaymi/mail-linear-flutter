# Mail Linear Flutter

Mail Linear Flutter is a Windows desktop mail manager built with a Flutter UI and a local Rust sidecar. The Flutter shell handles the desktop experience for Outlook and ClawEmail workflows, while `native-mail-api` provides the local HTTP API, mail fetching, cache, and Claw adapter.

## Repository Layout

- `mail_linear_flutter/` - Flutter desktop application.
- `native-mail-api/` - Rust sidecar used by the Flutter app.
- `docs/` - project notes and migration docs.

## Build

Requirements:

- Flutter 3.41 or newer with Windows desktop support.
- Rust stable toolchain.
- Visual Studio Build Tools with Windows desktop C++ components.

Build the native sidecar:

```powershell
cd native-mail-api
cargo build --release
```

Build the Flutter app:

```powershell
cd mail_linear_flutter
flutter pub get
flutter test --no-pub
flutter analyze --no-pub
flutter build windows --release
```

For a distributable Windows folder, copy the sidecar into the Flutter release output:

```powershell
New-Item -ItemType Directory -Force build\windows\x64\runner\Release\runtime\native
Copy-Item ..\native-mail-api\target\release\outlook-mail-native.exe build\windows\x64\runner\Release\runtime\native\
```

## License

This project is open source under the GNU General Public License v3.0. See `LICENSE`.
