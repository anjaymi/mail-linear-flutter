import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/models/mail_item.dart';
import '../../core/motion/motion_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/motion_widgets.dart';
import 'mail_empty_state.dart';
import 'mail_reader.dart';

/// ProMail-style mail page: narrow list (~260) + divider + flex reader.
class MailPage extends StatelessWidget {
  const MailPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 260,
          child: RepaintBoundary(child: _MailList(state: state)),
        ),
        const VerticalDivider(width: 1, thickness: 0.5, color: LinearColors.line),
        Expanded(child: MailReader(state: state)),
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
    final mails = state.filteredMails;
    return Container(
      color: LinearColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Text(
                  state.mailFilter == MailFilter.codes
                      ? state.text.ui('验证码邮件')
                      : state.text.ui('收件箱'),
                  style: AppText.sectionTitle.copyWith(fontSize: 16),
                ),
                if (mails.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${mails.length}',
                    style: AppText.caption.copyWith(fontSize: 11, color: LinearColors.faint),
                  ),
                ],
                const Spacer(),
                Icon(Icons.filter_list, size: 18, color: LinearColors.faint),
              ],
            ),
          ),
          // selected account email bar
          if (state.selectedAccount != null)
            _AccountEmailBar(state: state),
          // notices
          if (state.error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: MailNotice(text: state.error, color: LinearColors.red),
            ),
          if (state.mailWarning.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: MailNotice(
                text: state.mailWarning,
                color: LinearColors.amber,
              ),
            ),
          // list
          Expanded(
            child: !hasMailbox || mails.isEmpty
                ? EmptyMailState(state: state)
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: mails.length,
                    itemBuilder: (context, index) {
                      final mail = mails[index];
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

/// ProMail tile: sender bold + time right / subject / preview one line.
/// No borders, no active bar. Selected = light grey bg.
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
        onTap: onTap,
        child: AnimatedContainer(
          duration: MotionTokens.duration(context, MotionTokens.normal),
          curve: MotionTokens.easeOut,
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          decoration: BoxDecoration(
            color: active ? LinearColors.surfaceSoft : Colors.transparent,
            border: active
                ? const Border(
                    left: BorderSide(color: LinearColors.ink, width: 3),
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // row 1: sender + time
              Row(
                children: [
                  Expanded(
                    child: Text(
                      mail.senderName.isEmpty ? mail.sender : mail.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _shortTime(mail.date),
                    style: AppText.caption.copyWith(
                      fontSize: 11,
                      color: LinearColors.faint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // row 2: subject
              Text(
                mail.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  fontSize: 12.5,
                  color: LinearColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              // row 3: preview
              Text(
                mail.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.muted.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortTime(String value) {
    if (value.length >= 16) return value.substring(11, 16);
    if (value.length >= 10) return value.substring(5, 10);
    return value;
  }
}

/// Shows the currently selected account email + copy + marker color popup
/// below the mail list header.
class _AccountEmailBar extends StatelessWidget {
  const _AccountEmailBar({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final account = state.selectedAccount!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: LinearColors.line, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: account.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              account.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(fontSize: 12, color: LinearColors.ink),
            ),
          ),
          // copy
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () {
              Clipboard.setData(ClipboardData(text: account.email));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.text.ui('已复制'))),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy_outlined, size: 14, color: LinearColors.muted),
            ),
          ),
          const SizedBox(width: 4),
          // marker color popup
          PopupMenuButton<String>(
            tooltip: state.text.ui('标记颜色'),
            onSelected: (color) => state.setAccountMarker(account.id, color),
            offset: const Offset(0, 28),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            itemBuilder: (context) => [
              for (final opt in _markerOpts)
                PopupMenuItem(
                  value: opt.$2,
                  height: 32,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: opt.$3, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(opt.$1, style: AppText.body.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: '',
                height: 32,
                child: Text(
                  state.text.ui('清除'),
                  style: AppText.body.copyWith(fontSize: 12, color: LinearColors.muted),
                ),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.palette_outlined, size: 14, color: LinearColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

const _markerOpts = [
  ('蓝', '#3b6df6', Color(0xff3b6df6)),
  ('绿', '#18b981', Color(0xff18b981)),
  ('橙', '#f59e0b', Color(0xfff59e0b)),
  ('红', '#ef4444', Color(0xffef4444)),
  ('紫', '#7c3aed', Color(0xff7c3aed)),
  ('青', '#0ea5e9', Color(0xff0ea5e9)),
];
