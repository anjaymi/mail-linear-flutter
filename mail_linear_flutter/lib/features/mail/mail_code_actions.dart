import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';

class MailCodeActions extends StatelessWidget {
  const MailCodeActions({
    super.key,
    required this.state,
    required this.code,
    required this.body,
    required this.onCopy,
  });

  final AppState state;
  final String? code;
  final String body;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.text.ui('快捷动作'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          label: state.text.ui('复制验证码'),
          detail: code == null ? state.text.ui('未识别到数字验证码') : code!,
          icon: Icons.password_outlined,
          enabled: code != null,
          primary: true,
          onTap: code == null ? null : () => onCopy(code!),
        ),
        const SizedBox(height: 10),
        _ActionTile(
          label: state.text.ui('复制正文'),
          detail: body.isEmpty
              ? state.text.ui('当前邮件没有正文缓存')
              : state.text.ui('复制当前邮件纯文本'),
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
