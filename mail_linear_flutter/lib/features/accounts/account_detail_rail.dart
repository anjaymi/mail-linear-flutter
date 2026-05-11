import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/models/mail_account.dart';
import '../../core/motion/motion_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/motion_widgets.dart';
import 'account_marker_palette.dart';

/// Account detail rail rewritten to match the Figma prototype (Superhuman /
/// Apple Mail aesthetic). No nested cards, warm neutrals, a single column of
/// clearly-ranked blocks: identity → meta → actions → marker palette →
/// batch footer.
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (account == null)
            const _EmptyDetail()
          else
            _AccountDetail(account: account, state: state),
          const SizedBox(height: 24),
          const _Divider(),
          const SizedBox(height: 16),
          _BatchBar(
            state: state,
            selectedIds: selectedIds,
            onDeleted: onDeleted,
          ),
        ],
      ),
    );
  }
}

// ─── identity + meta + actions + marker ──────────────────────────────

class _AccountDetail extends StatelessWidget {
  const _AccountDetail({required this.account, required this.state});
  final MailAccount account;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IdentityRow(account: account, state: state),
        const SizedBox(height: 14),
        _MetaBlock(account: account, state: state),
        const SizedBox(height: 18),
        _PrimaryActions(account: account, state: state),
        const SizedBox(height: 20),
        Text(
          state.text.ui('账号标记'),
          style: AppText.label.copyWith(letterSpacing: 0.4),
        ),
        const SizedBox(height: 10),
        AccountMarkerPalette(
          state: state,
          value: account.markerColor,
          onChanged: (color) => state.setAccountMarker(account.id, color),
          compact: true,
        ),
      ],
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.account, required this.state});
  final MailAccount account;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final letter = account.email.isEmpty ? '?' : account.email[0].toUpperCase();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Avatar(color: account.color, letter: letter),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.email,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.itemTitle.copyWith(
                  fontSize: 15,
                  height: 1.3,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 4),
              _StatusDot(account: account, state: state),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.color, required this.letter});
  final Color color;
  final String letter;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MotionTokens.duration(context, MotionTokens.normal),
      curve: MotionTokens.easeOut,
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        letter,
        style: AppText.bodyStrong.copyWith(
          color: Colors.white,
          fontSize: 15,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// Status dot + label row, never a pill. Preserves the green/amber/red info
/// contract but renders quietly so the email address stays dominant.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.account, required this.state});
  final MailAccount account;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch ((state.checkingAccounts, account.isError)) {
      (true, true)  => (LinearColors.blue, state.text.ui('复检中')),
      (_, true)     => (LinearColors.red, state.text.ui('账号异常')),
      _             => (LinearColors.green, state.text.ui('可用')),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppText.caption.copyWith(color: color, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({required this.account, required this.state});
  final MailAccount account;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final sync = account.lastSyncedAt.isEmpty
        ? state.text.ui('等待同步')
        : account.lastSyncedAt;
    final client = _short(account.clientId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetaRow(
          label: state.text.ui('最近刷新'),
          value: sync,
        ),
        const SizedBox(height: 8),
        _MetaRow(
          label: 'Client ID',
          value: client.isEmpty ? '—' : client,
          monospace: true,
        ),
      ],
    );
  }

  static String _short(String value) => value.length <= 12
      ? value
      : '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });
  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: AppText.caption.copyWith(color: LinearColors.faint),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(
              fontSize: 12.5,
              color: LinearColors.ink,
              fontFeatures: monospace
                  ? const [FontFeature.tabularFigures()]
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({required this.account, required this.state});
  final MailAccount account;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: LinearButton(
            label: state.fetching
                ? state.text.fetching
                : state.text.ui('立即收取'),
            icon: Icons.mark_email_unread_outlined,
            primary: true,
            busy: state.fetching,
            onPressed: state.fetching ? null : state.fetchSelectedMail,
          ),
        ),
        const SizedBox(width: 8),
        _IconButton(
          tooltip: state.text.ui('复制邮箱'),
          icon: Icons.copy_outlined,
          onPressed: () => _copyAccount(context, account),
        ),
        const SizedBox(width: 4),
        _IconButton(
          tooltip: state.text.ui('在浏览器打开'),
          icon: Icons.open_in_new,
          onPressed: () {},
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
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MotionTapSurface(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            onTap: onPressed,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: LinearColors.line),
              ),
              child: Icon(icon, size: 16, color: LinearColors.muted),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── batch footer ────────────────────────────────────────────────────

class _BatchBar extends StatelessWidget {
  const _BatchBar({
    required this.state,
    required this.selectedIds,
    required this.onDeleted,
  });

  final AppState state;
  final List<int> selectedIds;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final empty = selectedIds.isEmpty;
    return Row(
      children: [
        Expanded(
          child: Text(
            empty
                ? state.text.ui('批量操作：先在列表中勾选账号')
                : state.text.selectedAccounts(selectedIds.length),
            maxLines: 2,
            style: AppText.caption.copyWith(
              color: empty ? LinearColors.faint : LinearColors.muted,
              fontSize: 11.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _BatchIcon(
          icon: Icons.sync,
          label: state.text.ui('收取'),
          enabled: !empty && !state.fetching,
          onPressed: () => state.fetchAccounts(selectedIds),
        ),
        const SizedBox(width: 4),
        _BatchIcon(
          icon: Icons.delete_outline,
          label: state.text.ui('删除'),
          danger: true,
          enabled: !empty,
          onPressed: () async {
            await state.deleteAccounts(selectedIds);
            onDeleted();
          },
        ),
      ],
    );
  }
}

class _BatchIcon extends StatelessWidget {
  const _BatchIcon({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final bool enabled;
  final bool danger;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? LinearColors.faint
        : danger
        ? LinearColors.red
        : LinearColors.ink;
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          onTap: enabled ? onPressed : null,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: LinearColors.line),
            ),
            child: Icon(icon, size: 15, color: fg),
          ),
        ),
      ),
    );
  }
}

// ─── empty + helpers ─────────────────────────────────────────────────

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: LinearColors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(
            Icons.alternate_email,
            size: 18,
            color: LinearColors.faint,
          ),
        ),
        const SizedBox(height: 14),
        Text('未选择账号', style: AppText.itemTitle.copyWith(fontSize: 14)),
        const SizedBox(height: 6),
        Text(
          '点击左侧任一账号查看状态、触发收件、更改标记。',
          style: AppText.caption.copyWith(
            color: LinearColors.muted,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: LinearColors.line);
  }
}
