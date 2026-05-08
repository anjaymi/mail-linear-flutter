import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/models/mail_account.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/status_pill.dart';
import 'account_marker_palette.dart';

class AccountRail extends StatelessWidget {
  const AccountRail({
    super.key,
    required this.state,
    required this.selectedIds,
    required this.onDeleted,
  });

  final AppState state;
  final List<int> selectedIds;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final account = state.selectedAccount;
    return Column(
      children: [
        _RailCard(
          child: account == null
              ? _EmptyAccountDetail(state: state)
              : _SelectedAccount(account: account, state: state),
        ),
        const SizedBox(height: 18),
        _RailCard(
          child: _BatchActions(
            state: state,
            selectedIds: selectedIds,
            onDeleted: onDeleted,
          ),
        ),
      ],
    );
  }
}

class _BatchActions extends StatelessWidget {
  const _BatchActions({
    required this.state,
    required this.selectedIds,
    required this.onDeleted,
  });

  final AppState state;
  final List<int> selectedIds;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.text.ui('批量操作'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          state.text.selectedAccounts(selectedIds.length),
          style: AppText.muted,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: LinearButton(
                label: state.text.ui('批量收件'),
                icon: Icons.sync,
                primary: true,
                onPressed: selectedIds.isEmpty || state.fetching
                    ? null
                    : () => state.fetchAccounts(selectedIds),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LinearButton(
                label: state.text.ui('删除'),
                icon: Icons.delete_outline,
                onPressed: selectedIds.isEmpty
                    ? null
                    : () async {
                        await state.deleteAccounts(selectedIds);
                        onDeleted();
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SelectedAccount extends StatelessWidget {
  const _SelectedAccount({required this.account, required this.state});
  final MailAccount account;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final letter = account.email.isEmpty ? '?' : account.email[0].toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: account.color,
              child: Text(
                letter,
                style: AppText.bodyStrong.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.email,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  StatusPill(
                    label: state.text.ui(account.isError ? '异常' : '可用'),
                    color: account.isError
                        ? LinearColors.red
                        : LinearColors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _InfoLine(
          state: state,
          label: state.text.ui('最近刷新'),
          value: account.lastSyncedAt,
        ),
        _InfoLine(
          state: state,
          label: 'Client ID',
          value: _short(account.clientId),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: LinearButton(
                label: state.text.ui('立即收取'),
                icon: Icons.mail_outline,
                primary: true,
                onPressed: state.fetchSelectedMail,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LinearButton(
                label: state.text.ui('复制邮箱'),
                icon: Icons.copy,
                onPressed: () => _copyAccount(context, account),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AccountMarkerPalette(
          state: state,
          value: account.markerColor,
          onChanged: (color) => state.setAccountMarker(account.id, color),
        ),
      ],
    );
  }

  Future<void> _copyAccount(BuildContext context, MailAccount account) async {
    await Clipboard.setData(ClipboardData(text: account.email));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(state.text.ui('邮箱地址已复制'))));
  }

  String _short(String value) => value.length <= 12
      ? value
      : '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
}

class _RailCard extends StatelessWidget {
  const _RailCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppSurfaces.panel(),
      child: child,
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.state,
    required this.label,
    required this.value,
  });

  final AppState state;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 78, child: Text(label, style: AppText.caption)),
          Expanded(
            child: Text(
              value.isEmpty ? state.text.ui('等待同步') : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppText.bodyStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAccountDetail extends StatelessWidget {
  const _EmptyAccountDetail({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.text.ui('选择账号'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(state.text.ui('点击左侧账号后，可查看状态、标记颜色并执行收件。'), style: AppText.muted),
      ],
    );
  }
}
