# Mail Linear Flutter

Mail Linear Flutter 的 Flutter 桌面 UI 工程。

这个目录只包含 Flutter 壳。实际收件、本地数据库、Outlook / ClawEmail API 适配由仓库根目录下的 `native-mail-api` Rust sidecar 负责。

开发时应用会查找：

- `../native-mail-api/target/release/outlook-mail-native.exe`
- 或打包后的 `runtime/native/outlook-mail-native.exe`

## 本地检查

```powershell
flutter test --no-pub
flutter analyze --no-pub
flutter build windows --release
```

## 打包提醒

Flutter release 构建完成后，需要把 Rust sidecar 复制到：

```text
build\windows\x64\runner\Release\runtime\native\outlook-mail-native.exe
```

否则应用启动时会提示找不到本地 API。

## 协议

GPL-3.0，详见仓库根目录 `LICENSE`。
