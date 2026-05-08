import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/status_pill.dart';
import 'account_detail_rail.dart';
import 'browser_login_dialog.dart';
import 'account_import_dialog.dart';
import 'account_row.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, required this.state});
  final AppState state;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.mode == WorkMode.claw) {
      return _ClawAccountsPage(state: state);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            decoration: AppSurfaces.panel(),
            child: Column(
              children: [
                _Toolbar(state: state, selectedCount: selected.length),
                const SizedBox(height: 18),
                _HeaderRow(),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.accounts.length,
                    itemBuilder: (context, index) {
                      final account = state.accounts[index];
                      return AccountRow(
                        account: account,
                        active: account.id == state.selectedAccount?.id,
                        checked: selected.contains(account.id),
                        onCheck: (value) => setState(
                          () => value
                              ? selected.add(account.id)
                              : selected.remove(account.id),
                        ),
                        onTap: () => state.selectAccount(account),
                        onDelete: () => state.deleteAccount(account.id),
                        onMarker: (color) =>
                            state.setAccountMarker(account.id, color),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 22),
        SizedBox(
          width: 340,
          child: AccountRail(
            state: state,
            selectedIds: selected.toList(),
            onDeleted: () => setState(selected.clear),
          ),
        ),
      ],
    );
  }
}

class _ClawAccountsPage extends StatelessWidget {
  const _ClawAccountsPage({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedClawMailbox;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            decoration: AppSurfaces.panel(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Claw 子邮箱',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    LinearButton(
                      label: '同步',
                      icon: Icons.sync_alt,
                      onPressed: state.refresh,
                    ),
                    const SizedBox(width: 10),
                    LinearButton(
                      label: 'Claw 设置',
                      icon: Icons.hub_outlined,
                      primary: true,
                      onPressed: () => state.setPage(AppPage.claw),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '当前显示 ClawEmail 子邮箱，不混用 Outlook 令牌账号。',
                  style: AppText.muted,
                ),
                const SizedBox(height: 20),
                const _ClawHeaderRow(),
                Expanded(
                  child: state.clawMailboxes.isEmpty
                      ? const Center(
                          child: Text('暂无 Claw 子邮箱', style: AppText.muted),
                        )
                      : ListView.builder(
                          itemCount: state.clawMailboxes.length,
                          itemBuilder: (context, index) {
                            final mailbox = state.clawMailboxes[index];
                            final email = state.clawMailboxEmail(mailbox);
                            final active =
                                selected != null &&
                                state.clawMailboxEmail(selected) == email;
                            return _ClawMailboxRow(
                              email: email,
                              mailbox: mailbox,
                              active: active,
                              onTap: () => state.loadCachedClawMails(mailbox),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 22),
        SizedBox(width: 340, child: _ClawAccountRail(state: state)),
      ],
    );
  }
}

class _ClawHeaderRow extends StatelessWidget {
  const _ClawHeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: LinearColors.muted,
      fontSize: 12,
      height: 1.25,
      fontWeight: FontWeight.w600,
    );
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 8, 10),
      child: Row(
        children: [
          Expanded(child: Text('子邮箱', style: style)),
          SizedBox(width: 120, child: Text('类型', style: style)),
          SizedBox(width: 96, child: Text('状态', style: style)),
          SizedBox(width: 64, child: Text('操作', style: style)),
        ],
      ),
    );
  }
}

class _ClawMailboxRow extends StatelessWidget {
  const _ClawMailboxRow({
    required this.email,
    required this.mailbox,
    required this.active,
    required this.onTap,
  });

  final String email;
  final Map<String, dynamic> mailbox;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = mailbox['mailbox_type']?.toString() ?? 'Claw';
    final status = mailbox['status']?.toString() ?? 'active';
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 66,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
        decoration: BoxDecoration(
          color: active
              ? LinearColors.blue.withValues(alpha: .09)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? LinearColors.blue.withValues(alpha: .24)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                email.isEmpty ? '未命名子邮箱' : email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.itemTitle,
              ),
            ),
            SizedBox(width: 120, child: Text(type, style: AppText.caption)),
            SizedBox(
              width: 96,
              child: StatusPill(
                label: status == 'active' ? '可用' : status,
                color: status == 'active'
                    ? LinearColors.green
                    : LinearColors.amber,
              ),
            ),
            SizedBox(
              width: 64,
              child: IconButton(
                tooltip: '复制子邮箱',
                onPressed: () => _copy(context, email),
                icon: const Icon(Icons.copy, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String email) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Claw 子邮箱已复制')));
  }
}

class _ClawAccountRail extends StatelessWidget {
  const _ClawAccountRail({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final mailbox = state.selectedClawMailbox;
    final email = mailbox == null ? '' : state.clawMailboxEmail(mailbox);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppSurfaces.panel(),
      child: mailbox == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('选择子邮箱', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('点击左侧 Claw 子邮箱后查看状态。', style: AppText.muted),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: LinearColors.blue,
                  child: Text(
                    email.isEmpty ? 'C' : email[0].toUpperCase(),
                    style: AppText.bodyStrong.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  email.isEmpty ? '未命名子邮箱' : email,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                StatusPill(
                  label: mailbox['status']?.toString() ?? 'active',
                  color: LinearColors.green,
                ),
                const SizedBox(height: 18),
                _ClawInfoLine(
                  label: '类型',
                  value: mailbox['mailbox_type']?.toString() ?? 'Claw',
                ),
                _ClawInfoLine(
                  label: '来源',
                  value: mailbox['source']?.toString() ?? 'ClawEmail',
                ),
                const SizedBox(height: 18),
                LinearButton(
                  label: '查看邮件',
                  icon: Icons.mail_outline,
                  primary: true,
                  onPressed: () async {
                    await state.loadCachedClawMails(mailbox);
                    state.setPage(AppPage.mail);
                  },
                ),
                const SizedBox(height: 10),
                LinearButton(
                  label: 'Claw 收件',
                  icon: Icons.sync,
                  onPressed: state.fetching ? null : state.fetchSelectedMail,
                ),
                const SizedBox(height: 10),
                LinearButton(
                  label: '复制子邮箱',
                  icon: Icons.copy,
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: email)),
                ),
              ],
            ),
    );
  }
}

class _ClawInfoLine extends StatelessWidget {
  const _ClawInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(label, style: AppText.caption)),
          Expanded(
            child: Text(
              value,
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

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.state, required this.selectedCount});
  final AppState state;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onSubmitted: (_) => state.refresh(),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜索邮箱、名称或 client id',
                ),
              ),
            ),
            const SizedBox(width: 12),
            LinearButton(
              label: '刷新',
              icon: Icons.refresh,
              onPressed: state.refresh,
            ),
            const SizedBox(width: 10),
            StatusPill(label: '已选 $selectedCount'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Spacer(),
            LinearButton(
              label: '浏览器授权',
              icon: Icons.login,
              onPressed: () => showBrowserLoginDialog(context, state),
            ),
            const SizedBox(width: 10),
            LinearButton(
              label: '批量导入',
              icon: Icons.add,
              primary: true,
              onPressed: () => showAccountImportDialog(context, state),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: LinearColors.muted,
      fontSize: 12,
      height: 1.25,
      fontWeight: FontWeight.w600,
    );
    return const Padding(
      padding: EdgeInsets.fromLTRB(50, 0, 8, 10),
      child: Row(
        children: [
          Expanded(child: Text('账号信息', style: style)),
          SizedBox(width: 78, child: Text('标记', style: style)),
          SizedBox(width: 82, child: Text('状态', style: style)),
          SizedBox(
            width: 142,
            child: Text('操作', textAlign: TextAlign.center, style: style),
          ),
        ],
      ),
    );
  }
}
