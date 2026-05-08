import 'package:flutter/services.dart';

abstract final class WindowControls {
  static const _channel = MethodChannel('outlook_mail_manager/window');

  static Future<void> drag() => _invoke('drag');

  static Future<void> minimize() => _invoke('minimize');

  static Future<void> toggleMaximize() => _invoke('toggleMaximize');

  static Future<void> close() => _invoke('close');

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Keeps debug runs on unsupported platforms harmless.
    }
  }
}
