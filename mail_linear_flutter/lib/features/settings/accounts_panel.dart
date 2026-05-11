import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/models/mail_account.dart';
import '../../core/theme/app_theme.dart';
import '../accounts/account_import_dialog.dart';
import '../accounts/browser_login_dialog.dart';

/// Accounts panel — single column, no right rail.
/// Selected account expands inline with detail + actions.
class AccountsPanel extends StatefulWidget {
  const AccountsPanel({super.key, required this.state});

  final AppState state;

  @override
  State<AccountsPanel> createState() => _AccountsPanelState();
}

class _AccountsPanelState extends State<AccountsPanel> {
  final selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(state: state, selected: selected, onClear: () => setState(selected.clear)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.accounts.length,
            itemBuilder: (context, index) {
              final account = state.accounts[index];
              final isActive = account.id == state.selectedAccount?.id;
              return _AccountItem(
                state: state,
                account: account,
                active: isActive,
                checked: selected.contains(account.id),
                onCheck: (v) => setState(
                  () => v
                      ? selected.add(account.id)
                      : selected.remove(account.id),
                ),
                onTap: () => state.selectAccount(account, openMail: false),
                onDelete: () => state.deleteAccount(account.id),
                onMarker: (color) => state.setAccountMarker(account.id, color),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.state,
    required this.selected,
    required this.onClear,
  });
  final AppState state;
  final Set<int> selected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 34,
              child: TextField(
                onSubmitted: (_) => state.refresh(),
                style: AppText.body,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 16),
                  prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 34),
                  hintText: state.text.ui('搜索账号…'),
                  hintStyle: AppText.muted.copyWith(fontSize: 12.5),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  filled: true,
                  fillColor: LinearColors.surfaceSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    borderSide: const BorderSide(color: LinearColors.blue, width: 1.2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _Btn(
            label: state.checkingAccounts ? state.text.ui('检查中') : state.text.ui('检查'),
            icon: Icons.fact_check_outlined,
            onPressed: state.checkingAccounts ? null : () => state.checkOutlookAccounts(),
          ),
          const SizedBox(width: 6),
          _Btn(
            label: state.text.ui('授权'),
            icon: Icons.login,
            onPressed: () => showBrowserLoginDialog(context, state),
          ),
          const SizedBox(width: 6),
          _Btn(
            label: state.text.ui('导入'),
            icon: Icons.add,
            primary: true,
            onPressed: () => showAccountImportDialog(context, state),
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(width: 10),
            _Btn(
              label: state.text.ui('批量收取'),
              icon: Icons.sync,
              onPressed: state.fetching ? null : () => state.fetchAccounts(selected.toList()),
            ),
            const SizedBox(width: 6),
            _Btn(
              label: state.text.ui('批量删除'),
              icon: Icons.delete_outline,
              color: LinearColors.red,
              onPressed: () async {
                await state.deleteAccounts(selected.toList());
                onClear();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.color,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? (primary ? LinearColors.surface : LinearColors.ink);
    final bg = primary ? LinearColors.ink : LinearColors.surfaceSoft;
    return SizedBox(
      height: 32,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14, color: onPressed == null ? LinearColors.faint : fg),
        label: Text(
          label,
          style: AppText.body.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: onPressed == null ? LinearColors.faint : fg,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: primary ? bg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            side: primary
                ? BorderSide.none
                : const BorderSide(color: LinearColors.line, width: 0.5),
          ),
        ),
      ),
    );
  }
}

/// Account row + inline expandable detail when active.
class _AccountItem extends StatelessWidget {
  const _AccountItem({
    required this.state,
    required this.account,
    required this.active,
    required this.checked,
    required this.onCheck,
    required this.onTap,
    required this.onDelete,
    required this.onMarker,
  });

  final AppState state;
  final MailAccount account;
  final bool active;
  final bool checked;
  final ValueChanged<bool> onCheck;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<String> onMarker;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // main row
        Material(
          color: active ? LinearColors.surfaceSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Checkbox(
                      value: checked,
                      onChanged: (v) => onCheck(v ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: account.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      account.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (account.lastSyncedAt.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        account.lastSyncedAt,
                        style: AppText.caption.copyWith(
                          fontSize: 11,
                          color: LinearColors.faint,
                        ),
                      ),
                    ),
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: account.isError ? LinearColors.red : LinearColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  _MiniIcon(Icons.copy_outlined, () {
                    Clipboard.setData(ClipboardData(text: account.email));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.text.ui('已复制'))),
                    );
                  }),
                  const SizedBox(width: 4),
                  _MiniIcon(Icons.close, onDelete, color: LinearColors.red),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
        // inline detail (only when active)
        if (active) _InlineDetail(state: state, account: account, onMarker: onMarker),
      ],
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon(this.icon, this.onTap, {this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 15, color: color ?? LinearColors.faint),
      ),
    );
  }
}

/// Inline expanded detail: single row — status + client id + fetch btn + marker popup.
class _InlineDetail extends StatelessWidget {
  const _InlineDetail({
    required this.state,
    required this.account,
    required this.onMarker,
  });
  final AppState state;
  final MailAccount account;
  final ValueChanged<String> onMarker;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 40, right: 8, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: LinearColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          // status
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: account.isError ? LinearColors.red : LinearColors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            account.isError ? state.text.ui('异常') : state.text.ui('可用'),
            style: AppText.caption.copyWith(
              fontSize: 11,
              color: account.isError ? LinearColors.red : LinearColors.green,
            ),
          ),
          const SizedBox(width: 14),
          // client id
          Text(
            'ID ${_short(account.clientId)}',
            style: AppText.caption.copyWith(fontSize: 11, color: LinearColors.faint),
          ),
          const Spacer(),
          // fetch button
          SizedBox(
            height: 26,
            child: FilledButton.icon(
              onPressed: state.fetching ? null : () async {
                await state.selectAccount(account);
                await state.fetchSelectedMail();
              },
              icon: const Icon(Icons.mark_email_unread_outlined, size: 13),
              label: Text(state.fetching ? state.text.fetching : state.text.ui('收取')),
              style: FilledButton.styleFrom(
                backgroundColor: LinearColors.ink,
                foregroundColor: LinearColors.surface,
                disabledBackgroundColor: LinearColors.surfaceSoft,
                disabledForegroundColor: LinearColors.faint,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                textStyle: AppText.body.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // marker color popup
          PopupMenuButton<String>(
            tooltip: state.text.ui('标记颜色'),
            onSelected: onMarker,
            offset: const Offset(0, 28),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            itemBuilder: (context) => [
              for (final opt in _colors)
                PopupMenuItem(
                  value: opt.value,
                  height: 32,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: opt.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(opt.label, style: AppText.body.copyWith(fontSize: 12)),
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
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: LinearColors.line, width: 0.5),
              ),
              child: Icon(
                Icons.palette_outlined,
                size: 14,
                color: account.markerColor.isNotEmpty
                    ? account.color
                    : LinearColors.faint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _short(String value) => value.length <= 10
      ? value
      : '${value.substring(0, 5)}…${value.substring(value.length - 4)}';
}

class _MC {
  const _MC(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
}

const _colors = [
  _MC('蓝', '#3b6df6', Color(0xff3b6df6)),
  _MC('绿', '#18b981', Color(0xff18b981)),
  _MC('橙', '#f59e0b', Color(0xfff59e0b)),
  _MC('红', '#ef4444', Color(0xffef4444)),
  _MC('紫', '#7c3aed', Color(0xff7c3aed)),
  _MC('青', '#0ea5e9', Color(0xff0ea5e9)),
];
