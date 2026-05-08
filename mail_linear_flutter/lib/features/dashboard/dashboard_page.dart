import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/metric_card.dart';
import '../../shared/widgets/status_pill.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final claw = state.mode == WorkMode.claw;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              SizedBox(
                height: 148,
                child: Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        value: '${state.stats.totalAccounts}',
                        label: claw ? 'Claw 子邮箱' : '已导入账号',
                        detail: claw ? '已同步列表' : '全部令牌已载入',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MetricCard(
                        value: '${state.stats.activeAccounts}',
                        label: claw ? '可用子邮箱' : '可立即收件',
                        detail: claw ? '通讯规则正常' : '等待同步',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MetricCard(
                        value: '${state.stats.totalInboxMails}',
                        label: '缓存邮件',
                        detail: '本地可读',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MetricCard(
                        value: '${state.stats.errorAccounts}',
                        label: '待处理异常',
                        detail: '优先修复',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(child: _QueuePanel(state: state)),
            ],
          ),
        ),
        const SizedBox(width: 28),
        SizedBox(width: 360, child: _RightRail(state: state)),
      ],
    );
  }
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final claw = state.mode == WorkMode.claw;
    final outlookItems = state.accounts.take(4).toList();
    final clawItems = state.clawMailboxes.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppSurfaces.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('今日收件队列', style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              LinearButton(
                label: claw ? 'Claw 设置' : '管理账号',
                icon: Icons.arrow_forward,
                onPressed: () =>
                    state.setPage(claw ? AppPage.claw : AppPage.accounts),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (claw && clawItems.isEmpty)
            const _EmptyQueue(claw: true)
          else if (!claw && outlookItems.isEmpty)
            const _EmptyQueue(claw: false)
          else if (claw)
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: clawItems.map((mailbox) {
                  final email = state.clawMailboxEmail(mailbox);
                  return _QueueRow(
                    state: state,
                    email: email.isEmpty ? '未命名子邮箱' : email,
                    color: LinearColors.blue,
                    detail:
                        '${mailbox['status'] ?? 'active'} · ${mailbox['mailbox_type'] ?? 'Claw'}',
                    onTap: () => state.loadCachedClawMails(mailbox),
                  );
                }).toList(),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: outlookItems
                    .map(
                      (account) => _QueueRow(
                        state: state,
                        email: account.email,
                        color: account.color,
                        detail: 'Outlook 令牌账号',
                        onTap: () =>
                            state.selectAccount(account, openMail: false),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.state,
    required this.email,
    required this.color,
    required this.detail,
    required this.onTap,
  });
  final AppState state;
  final String email;
  final Color color;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: LinearColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.itemTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const StatusPill(label: '可用'),
          ],
        ),
      ),
    );
  }
}

class _RightRail extends StatelessWidget {
  const _RightRail({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: AppSurfaces.accent(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('收件同步', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  const StatusPill(label: '待执行'),
                ],
              ),
              const SizedBox(height: 12),
              const Text('账号将同步到本地缓存，完成后可在邮件页直接阅读。', style: AppText.muted),
              const SizedBox(height: 20),
              LinearButton(
                label: state.mode == WorkMode.claw ? 'Claw 收件' : '开始收取',
                icon: Icons.sync,
                primary: true,
                onPressed:
                    state.fetching ||
                        (state.mode == WorkMode.claw
                            ? state.selectedClawMailbox == null
                            : state.selectedAccount == null)
                    ? null
                    : state.fetchSelectedMail,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Expanded(child: _RecentMails(state: state)),
      ],
    );
  }
}

class _RecentMails extends StatelessWidget {
  const _RecentMails({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final mails = state.stats.recentMails.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppSurfaces.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('最近邮件', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (mails.isEmpty)
            const Text('暂无邮件', style: AppText.muted)
          else
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: mails.map((mail) {
                  return _RecentMailRow(
                    subject: mail.subject,
                    sender: mail.sender,
                    onTap: () => state.openCachedMail(mail),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentMailRow extends StatelessWidget {
  const _RecentMailRow({
    required this.subject,
    required this.sender,
    required this.onTap,
  });

  final String subject;
  final String sender;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.itemTitle,
              ),
              const SizedBox(height: 6),
              Text(
                sender,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({required this.claw});
  final bool claw;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 32),
    child: Text(
      claw ? '暂无 Claw 子邮箱，先到 Claw 设置绑定并同步。' : '暂无账号，先导入 Outlook 令牌账号。',
      style: AppText.muted,
    ),
  );
}
