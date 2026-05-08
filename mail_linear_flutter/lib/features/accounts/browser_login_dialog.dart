import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';

const _defaultClientId = '9e5f94bc-e8a4-4e73-b8be-63364c29d753';

Future<void> showBrowserLoginDialog(BuildContext context, AppState state) {
  return showDialog<void>(
    context: context,
    builder: (_) => _BrowserLoginDialog(state: state),
  );
}

class _BrowserLoginDialog extends StatefulWidget {
  const _BrowserLoginDialog({required this.state});
  final AppState state;

  @override
  State<_BrowserLoginDialog> createState() => _BrowserLoginDialogState();
}

class _BrowserLoginDialogState extends State<_BrowserLoginDialog> {
  final clientId = TextEditingController(text: _defaultClientId);
  bool busy = false;
  bool polling = false;
  String? messageKey = '会打开系统浏览器完成 Microsoft 授权，成功后自动写入账号。';
  String? rawMessage;

  String get message => rawMessage ?? widget.state.text.ui(messageKey ?? '');

  @override
  void dispose() {
    polling = false;
    clientId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.state.text.ui('浏览器授权登录')),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.state.text.ui(
                '适合没有现成 refresh token 的普通 Outlook / Hotmail 账号。',
              ),
              style: TextStyle(
                color: LinearColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: clientId,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Azure Client ID',
                hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
              ),
            ),
            const SizedBox(height: 12),
            _StatusBox(message: message, active: polling),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(widget.state.text.ui('取消')),
        ),
        FilledButton(
          onPressed: busy ? null : _start,
          child: Text(widget.state.text.ui(polling ? '等待授权' : '打开浏览器')),
        ),
      ],
    );
  }

  Future<void> _start() async {
    final api = widget.state.api;
    final id = clientId.text.trim();
    if (api == null || id.isEmpty) return;
    setState(() {
      busy = true;
      polling = true;
      messageKey = '正在创建授权会话...';
      rawMessage = null;
    });

    try {
      final redirectUri = _redirectUri();
      final session = await api.startBrowserLogin(
        clientId: id,
        redirectUri: redirectUri,
      );
      final state = session['state']?.toString() ?? '';
      final url = session['authorization_url']?.toString() ?? '';
      if (state.isEmpty || url.isEmpty) {
        throw Exception(widget.state.text.ui('授权会话返回不完整。'));
      }

      await _openSystemBrowser(url);
      if (!mounted) return;
      setState(() {
        messageKey = '浏览器已打开，请完成登录授权。';
        rawMessage = null;
      });
      await _poll(state);
    } catch (ex) {
      if (!mounted) return;
      setState(() {
        busy = false;
        polling = false;
        rawMessage = ex.toString();
      });
    }
  }

  Future<void> _poll(String state) async {
    final api = widget.state.api;
    if (api == null) return;
    for (var i = 0; i < 300 && mounted && polling; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final result = await api.pollBrowserLogin(state);
      final status = result['status']?.toString() ?? 'pending';
      if (status == 'pending') continue;
      if (status == 'authorized') {
        await widget.state.refresh();
        final account = result['account'];
        final email = account is Map ? account['email']?.toString() : null;
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${email ?? widget.state.text.ui('账号')} ${widget.state.text.ui('已授权并导入')}',
            ),
          ),
        );
        return;
      }
      throw Exception(
        result['error']?.toString() ?? widget.state.text.ui('授权失败'),
      );
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      polling = false;
      messageKey = '授权等待超时，请重新打开浏览器授权。';
      rawMessage = null;
    });
  }

  String _redirectUri() {
    final uri = Uri.parse(widget.state.serverUrl);
    final port = uri.hasPort ? uri.port : 3000;
    return 'http://127.0.0.1:$port/api/oauth/browser/callback';
  }

  Future<void> _openSystemBrowser(String url) async {
    if (Platform.isWindows) {
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
      return;
    }
    if (Platform.isMacOS) {
      await Process.run('open', [url]);
      return;
    }
    await Process.run('xdg-open', [url]);
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({required this.message, required this.active});
  final String message;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? const Color(0xffeff6ff) : LinearColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? const Color(0xffbfdbfe) : LinearColors.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.sync : Icons.info_outline,
            color: active ? LinearColors.blue : LinearColors.muted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: LinearColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
