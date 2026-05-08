import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/models/mail_item.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/status_pill.dart';

class MailCodeRail extends StatelessWidget {
  const MailCodeRail({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final mail = state.selectedMail;
    final body = mail?.preview ?? '';
    final code = _extractCode(body);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppSurfaces.panel(radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RailHeader(hasMail: mail != null, hasCode: code != null),
          const SizedBox(height: 16),
          _CodeCard(code: code),
          const SizedBox(height: 16),
          _MailContext(mail: mail),
          const SizedBox(height: 16),
          _ActionGroup(
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
    ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.hasMail, required this.hasCode});

  final bool hasMail;
  final bool hasCode;

  @override
  Widget build(BuildContext context) {
    final status = !hasMail ? '待选择' : (hasCode ? '已识别' : '未识别');
    final color = !hasMail
        ? LinearColors.faint
        : (hasCode ? LinearColors.green : LinearColors.amber);
    return Row(
      children: [
        Expanded(
          child: Text('邮件助手', style: Theme.of(context).textTheme.titleLarge),
        ),
        StatusPill(label: status, color: color),
      ],
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

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
                active ? '验证码' : '等待识别',
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
          const Text('自动提取当前邮件正文中的 4-8 位数字。', style: AppText.caption),
        ],
      ),
    );
  }
}

class _MailContext extends StatelessWidget {
  const _MailContext({required this.mail});

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
          ? const _EmptyContext()
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
                _MetaLine(label: '日期', value: _shortDate(current.date)),
                _MetaLine(
                  label: '正文',
                  value: current.preview.isEmpty ? '无预览' : '已缓存',
                ),
              ],
            ),
    );
  }

  String _shortDate(String value) =>
      value.length > 10 ? value.substring(0, 10) : value;
}

class _EmptyContext extends StatelessWidget {
  const _EmptyContext();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('当前邮件', style: AppText.itemTitle),
        const SizedBox(height: 8),
        const Text('选择一封邮件后显示发件人、日期和缓存状态。', style: AppText.caption),
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

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({
    required this.code,
    required this.body,
    required this.onCopy,
  });

  final String? code;
  final String body;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('快捷动作', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _ActionTile(
          label: '复制验证码',
          detail: code == null ? '未识别到数字验证码' : code!,
          icon: Icons.password_outlined,
          enabled: code != null,
          primary: true,
          onTap: code == null ? null : () => onCopy(code!),
        ),
        const SizedBox(height: 10),
        _ActionTile(
          label: '复制正文',
          detail: body.isEmpty ? '当前邮件没有正文缓存' : '复制当前邮件纯文本',
          icon: Icons.copy_outlined,
          enabled: body.isNotEmpty,
          onTap: body.isEmpty ? null : () => onCopy(body),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.detail,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final String detail;
  final IconData icon;
  final bool enabled;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = primary ? LinearColors.blue : LinearColors.ink;
    return Material(
      color: enabled
          ? color.withValues(alpha: primary ? .10 : .04)
          : LinearColors.surfaceSoft.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 19, color: enabled ? color : LinearColors.faint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.bodyStrong.copyWith(
                        color: enabled ? LinearColors.ink : LinearColors.faint,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
