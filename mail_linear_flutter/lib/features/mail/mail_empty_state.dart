import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';

class EmptyMailState extends StatelessWidget {
  const EmptyMailState({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final hasMailbox = state.mode == WorkMode.claw
        ? state.selectedClawMailbox != null
        : state.selectedAccount != null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasMailbox
                ? Icons.mark_email_unread_outlined
                : state.mode == WorkMode.claw
                ? Icons.hub_outlined
                : Icons.alternate_email,
            size: 34,
            color: LinearColors.faint,
          ),
          const SizedBox(height: 12),
          Text(
            hasMailbox
                ? '暂无缓存邮件'
                : state.mode == WorkMode.claw
                ? '先选择一个 Claw 子邮箱'
                : '先选择一个账号',
            style: AppText.bodyStrong,
          ),
          const SizedBox(height: 8),
          Text(
            hasMailbox
                ? state.mode == WorkMode.claw
                      ? '点击收取后会从 Claw Coremail 拉取并写入本地缓存。'
                      : '点击收取后会显示 Graph / IMAP / 缓存来源。'
                : state.mode == WorkMode.claw
                ? '到 Claw 账号页选择子邮箱后再读取邮件。'
                : '到账号页选择邮箱后再读取邮件。',
            textAlign: TextAlign.center,
            style: AppText.muted,
          ),
          if (hasMailbox) ...[
            const SizedBox(height: 16),
            LinearButton(
              label: state.fetching ? '收取中' : '立即收取',
              icon: Icons.sync,
              primary: true,
              onPressed: state.fetching ? null : state.fetchSelectedMail,
            ),
          ],
        ],
      ),
    );
  }
}

class MailNotice extends StatelessWidget {
  const MailNotice({super.key, required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: AppText.bodyStrong.copyWith(color: color),
      ),
    );
  }
}
