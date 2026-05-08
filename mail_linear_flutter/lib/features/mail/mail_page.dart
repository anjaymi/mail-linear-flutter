import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/models/mail_item.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/status_pill.dart';
import 'mail_code_rail.dart';
import 'mail_empty_state.dart';

class MailPage extends StatelessWidget {
  const MailPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 360, child: _MailList(state: state)),
        const SizedBox(width: 18),
        Expanded(child: _Reader(state: state)),
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
                onPressed: state.refresh,
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
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
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
    );
  }

  String _shortDate(String value) =>
      value.length > 10 ? value.substring(0, 10) : value;
}

class _Reader extends StatelessWidget {
  const _Reader({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final mail = state.selectedMail;
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: AppSurfaces.panel(radius: 28),
      child: mail == null
          ? Center(child: Text(state.text.ui('选择一封邮件开始阅读')))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(label: state.text.ui('收件箱')),
                const SizedBox(height: 18),
                Text(
                  mail.subject,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  '${mail.senderName}  ${mail.sender}',
                  style: AppText.muted,
                ),
                const Divider(height: 36),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      mail.preview.isEmpty
                          ? state.text.ui('无正文预览。')
                          : mail.preview,
                      style: AppText.body.copyWith(fontSize: 16, height: 1.7),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
