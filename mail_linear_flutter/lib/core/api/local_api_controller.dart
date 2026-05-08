import 'dart:io';

import 'mail_api.dart';

class LocalApiController {
  Process? _process;
  int port = 3000;
  String get baseUrl => 'http://127.0.0.1:$port';

  Future<String> start() async {
    final exe = _findNativeExecutable();
    if (exe == null) {
      throw Exception('未找到 runtime/native/outlook-mail-native.exe');
    }

    port = await _findFreePort(3000);
    final env = Map<String, String>.from(Platform.environment)
      ..['PORT'] = '$port'
      ..['OUTLOOK_MANAGER_PARENT_PID'] = '$pid'
      ..['DB_PATH'] = _databasePath()
      ..['LEGACY_DB_PATHS'] = _legacyDatabasePaths().join(';');

    _process = await Process.start(
      exe.path,
      const [],
      workingDirectory: _workspaceRoot().path,
      environment: env,
      mode: ProcessStartMode.detachedWithStdio,
    );
    await _waitReady();
    return baseUrl;
  }

  Future<void> stop() async {
    _process?.kill();
    _process = null;
  }

  Future<void> _waitReady() async {
    final api = MailApi(baseUrl);
    try {
      for (var i = 0; i < 120; i++) {
        if (await api.check()) return;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    } finally {
      api.close();
    }
    throw Exception('18 秒内未检测到本地 API。');
  }

  Future<int> _findFreePort(int start) async {
    for (var candidate = start; candidate <= start + 30; candidate++) {
      try {
        final socket = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          candidate,
        );
        await socket.close();
        return candidate;
      } catch (_) {
        continue;
      }
    }
    throw Exception('没有找到可用端口。');
  }

  File? _findNativeExecutable() {
    for (final path in _nativeCandidates()) {
      final file = File(path);
      if (file.existsSync()) return file;
    }
    return null;
  }

  Iterable<String> _nativeCandidates() sync* {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final root = _workspaceRoot().path;
    yield '$exeDir\\runtime\\native\\outlook-mail-native.exe';
    yield '$exeDir\\outlook-mail-native.exe';
    yield '$root\\native-mail-api\\target\\release\\outlook-mail-native.exe';
    yield '$root\\LauncherWinUI\\runtime\\native\\outlook-mail-native.exe';
  }

  Directory _workspaceRoot() {
    var dir = Directory.current;
    while (dir.parent.path != dir.path) {
      if (Directory('${dir.path}\\native-mail-api').existsSync()) return dir;
      dir = dir.parent;
    }
    return Directory.current;
  }

  String _databasePath() {
    final base = Platform.environment['LOCALAPPDATA'] ?? Directory.current.path;
    final data = Directory('$base\\OutlookMailManager.WinUI\\data')
      ..createSync(recursive: true);
    return '${data.path}\\outlook.db';
  }

  Iterable<String> _legacyDatabasePaths() sync* {
    final root = _workspaceRoot().path;
    yield '$root\\server\\data\\outlook.db';
    yield '$root\\outlook-mail-manager\\server\\data\\outlook.db';
  }
}
