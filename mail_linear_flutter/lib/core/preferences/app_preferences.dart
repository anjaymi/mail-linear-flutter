import 'dart:convert';
import 'dart:io';

class AppPreferences {
  Future<bool> loadAutoReceiveEnabled() async {
    final data = await _read();
    return data['autoReceiveEnabled'] == true;
  }

  Future<int> loadAutoReceiveMinutes() async {
    final data = await _read();
    final value = (data['autoReceiveMinutes'] as num?)?.toInt() ?? 5;
    return value.clamp(1, 60);
  }

  Future<void> saveAutoReceiveEnabled(bool enabled) async {
    final data = await _read()
      ..['autoReceiveEnabled'] = enabled;
    final file = _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> saveAutoReceiveMinutes(int minutes) async {
    final data = await _read()
      ..['autoReceiveMinutes'] = minutes.clamp(1, 60);
    final file = _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data));
  }

  Future<bool> loadSoundEnabled() async {
    final data = await _read();
    return data['soundEnabled'] != false;
  }

  Future<String> loadSoundTone() async {
    final data = await _read();
    return data['soundTone']?.toString() ?? 'mail';
  }

  Future<void> saveSoundEnabled(bool enabled) async {
    final data = await _read()
      ..['soundEnabled'] = enabled;
    final file = _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> saveSoundTone(String tone) async {
    final data = await _read()
      ..['soundTone'] = tone;
    final file = _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data));
  }

  Future<Map<String, dynamic>> _read() async {
    final file = _file();
    if (!await file.exists()) return {};
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  File _file() {
    final base = Platform.environment['LOCALAPPDATA'] ?? Directory.current.path;
    return File('$base\\OutlookMailManager.WinUI\\settings.json');
  }
}
