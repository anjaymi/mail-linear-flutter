import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/models/mail_item.dart';
import '../../core/motion/motion_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/motion_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import 'mail_code_rail.dart';
import 'mail_empty_state.dart';
import 'mail_reader.dart';

class MailPage extends StatelessWidget {
  const MailPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 360, child: _MailList(state: state)),
        const SizedBox(width: 18),
        Expanded(child: MailReader(state: state)),
        const SizedBox(width: 18),
        SizedBox(width: 310, child: MailCodeRail(state: state)),
      ],
    );
  }
}

class _MailList extends StatelessWidget {
  const _MailList({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final hasMailbox = state.mode == WorkMode.claw
        ? state.selectedClawMailbox != null
        : state.selectedAccount != null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppSurfaces.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                state.text.ui('收件箱'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              StatusPill(label: state.mailSource, color: LinearColors.blue),
              const SizedBox(width: 8),
              IconButton(
                tooltip: state.text.ui('刷新当前邮箱缓存'),
                onPressed: state.refreshCurrentMailbox,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: state.text.ui('搜索邮件、验证码或发件人'),
            ),
          ),
          const SizedBox(height: 16),
          if (!hasMailbox)
            Text(
              state.text.ui(
                state.mode == WorkMode.claw
                    ? '先在 Claw 账号页选择子邮箱。'
                    : '先在账号页选择邮箱。',
              ),
            )
          else
            _FetchBar(state: state),
          const SizedBox(height: 12),
          if (state.error.isNotEmpty)
            MailNotice(text: state.error, color: LinearColors.red),
          if (state.mailWarning.isNotEmpty)
            MailNotice(text: state.mailWarning, color: LinearColors.amber),
          if (state.error.isNotEmpty || state.mailWarning.isNotEmpty)
            const SizedBox(height: 12),
          Expanded(
            child: state.mails.isEmpty
                ? EmptyMailState(state: state)
                : ListView.builder(
                    itemCount: state.mails.length,
                    itemBuilder: (context, index) {
                      final mail = state.mails[index];
                      return _MailTile(
                        mail: mail,
                        active: mail.id == state.selectedMail?.id,
                        onTap: () => state.selectMail(mail),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FetchBar extends StatelessWidget {
  const _FetchBar({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final email = state.mode == WorkMode.claw
        ? state.clawMailboxEmail(state.selectedClawMailbox!)
        : state.selectedAccount!.email;
    return Row(
      children: [
        Expanded(
          child: _AccountChip(
            email: email,
            icon: state.mode == WorkMode.claw
                ? Icons.hub_outlined
                : Icons.alternate_email,
          ),
        ),
        const SizedBox(width: 10),
        LinearButton(
          label: state.fetching ? state.text.fetching : state.text.ui('收取'),
          icon: Icons.sync,
          primary: true,
          busy: state.fetching,
          onPressed: state.fetching ? null : state.fetchSelectedMail,
        ),
      ],
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.email, required this.icon});

  final String email;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: LinearColors.green.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LinearColors.green.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: LinearColors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(color: LinearColors.green),
            ),
          ),
        ],
      ),
    );
  }
}

class _MailTile extends StatelessWidget {
  const _MailTile({
    required this.mail,
    required this.active,
    required this.onTap,
  });
  final MailItem mail;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MotionTapSurface(
      lift: false,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: MotionTokens.duration(context, MotionTokens.normal),
          curve: MotionTokens.easeOut,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active ? const Color(0xffedf4ff) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? const Color(0xffb7d1ff) : LinearColors.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MailboxBadge(mailbox: mail.mailbox),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mail.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.itemTitle,
                    ),
                  ),
                  Text(_shortDate(mail.date), style: AppText.caption),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                mail.senderName.isEmpty ? mail.sender : mail.senderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.muted,
              ),
              const SizedBox(height: 6),
              Text(
                mail.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortDate(String value) =>
      value.length > 10 ? value.substring(0, 10) : value;
}

class _MailboxBadge extends StatelessWidget {
  const _MailboxBadge({required this.mailbox});

  final String mailbox;

  @override
  Widget build(BuildContext context) {
    final normalized = mailbox.toLowerCase();
    final isJunk = normalized == 'junk';
    final label = isJunk ? 'Junk' : 'Inbox';
    final color = isJunk ? LinearColors.amber : LinearColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
