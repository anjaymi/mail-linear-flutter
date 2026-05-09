import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/models/mail_item.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/status_pill.dart';
import 'mail_code_actions.dart';

class MailCodeRail extends StatelessWidget {
  const MailCodeRail({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final mail = state.selectedMail;
    final body = mail?.bodyText ?? '';
    final code = _extractCode(body);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppSurfaces.panel(radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RailHeader(
            state: state,
            hasMail: mail != null,
            hasCode: code != null,
          ),
          const SizedBox(height: 16),
          _CodeCard(state: state, code: code),
          const SizedBox(height: 16),
          _MailContext(state: state, mail: mail),
          const SizedBox(height: 16),
          MailCodeActions(
            state: state,
            code: code,
            body: body,
            onCopy: (text) => _copy(context, text),
          ),
        ],
      ),
    );
  }

  String? _extractCode(String text) =>
      RegExp(r'\b\d{4,8}\b').firstMatch(text)?.group(0);

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(state.text.ui('已复制到剪贴板'))));
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({
    required this.state,
    required this.hasMail,
    required this.hasCode,
  });

  final AppState state;
  final bool hasMail;
  final bool hasCode;

  @override
  Widget build(BuildContext context) {
    final status = state.text.ui(!hasMail ? '待选择' : (hasCode ? '已识别' : '未识别'));
    final color = !hasMail
        ? LinearColors.faint
        : (hasCode ? LinearColors.green : LinearColors.amber);
    return Row(
      children: [
        Expanded(
          child: Text(
            state.text.ui('邮件助手'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        StatusPill(label: status, color: color),
      ],
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.state, required this.code});

  final AppState state;
  final String? code;

  @override
  Widget build(BuildContext context) {
    final active = code != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: active
            ? LinearColors.accentPanel.withValues(alpha: .82)
            : LinearColors.surfaceSoft.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: active
              ? LinearColors.blue.withValues(alpha: .20)
              : LinearColors.chromeLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                active ? Icons.verified_outlined : Icons.password_outlined,
                color: active ? LinearColors.blue : LinearColors.faint,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                state.text.ui(active ? '验证码' : '等待识别'),
                style: AppText.label.copyWith(
                  color: active ? LinearColors.blue : LinearColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            code ?? '----',
            style: AppText.display.copyWith(
              fontSize: active ? 34 : 30,
              fontWeight: FontWeight.w800,
              letterSpacing: active ? 2 : 6,
              color: active ? LinearColors.ink : LinearColors.faint,
            ),
          ),
          const SizedBox(height: 10),
          Text(state.text.ui('自动提取当前邮件正文中的 4-8 位数字。'), style: AppText.caption),
        ],
      ),
    );
  }
}

class _MailContext extends StatelessWidget {
  const _MailContext({required this.state, required this.mail});

  final AppState state;
  final MailItem? mail;

  @override
  Widget build(BuildContext context) {
    final current = mail;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LinearColors.chrome.withValues(alpha: .56),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LinearColors.chromeLine.withValues(alpha: .7),
        ),
      ),
      child: current == null
          ? _EmptyContext(state: state)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.itemTitle,
                ),
                const SizedBox(height: 8),
                Text(
                  current.senderName.isEmpty
                      ? current.sender
                      : '${current.senderName}  ${current.sender}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
                const SizedBox(height: 12),
                _MetaLine(
                  label: state.text.ui('日期'),
                  value: _shortDate(current.date),
                ),
                _MetaLine(
                  label: state.text.ui('正文'),
                  value: current.hasBody
                      ? state.text.ui('已缓存')
                      : state.text.ui('无预览'),
                ),
              ],
            ),
    );
  }

  String _shortDate(String value) =>
      value.length > 10 ? value.substring(0, 10) : value;
}

class _EmptyContext extends StatelessWidget {
  const _EmptyContext({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(state.text.ui('当前邮件'), style: AppText.itemTitle),
        const SizedBox(height: 8),
        Text(state.text.ui('选择一封邮件后显示发件人、日期和缓存状态。'), style: AppText.caption),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text(label, style: AppText.caption),
          const Spacer(),
          Text(value, style: AppText.bodyStrong),
        ],
      ),
    );
  }
}
