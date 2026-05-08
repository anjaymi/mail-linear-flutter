# Mail Linear Flutter

Flutter desktop shell for the Mail Linear / Outlook Mail Manager app.

The app talks to the local Rust sidecar in `../native-mail-api` during development, or to `runtime/native/outlook-mail-native.exe` when packaged.

## Local Checks

```powershell
flutter test --no-pub
flutter analyze --no-pub
flutter build windows --release
```

## License

GPL-3.0. See the repository root `LICENSE`.
