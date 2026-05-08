import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/status_pill.dart';

class ClawSettingsPanel extends StatefulWidget {
  const ClawSettingsPanel({super.key, required this.state});

  final AppState state;

  @override
  State<ClawSettingsPanel> createState() => _ClawSettingsPanelState();
}

class _ClawSettingsPanelState extends State<ClawSettingsPanel> {
  final email = TextEditingController();
  final code = TextEditingController();
  final suffix = TextEditingController();
  Map<String, dynamic> status = {};
  List<Map<String, dynamic>> mailboxes = [];
  String message = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    email.dispose();
    code.dispose();
    suffix.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String ok) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await action();
      await _load(silent: true);
      setState(() => message = ok);
    } catch (ex) {
      setState(() => message = ex.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _load({bool silent = false}) async {
    final api = widget.state.api;
    if (api == null) return;
    if (!silent) setState(() => busy = true);
    try {
      final nextStatus = await api.clawStatus();
      final nextMailboxes = await api.clawMailboxes();
      setState(() {
        status = nextStatus;
        mailboxes = nextMailboxes;
      });
    } catch (ex) {
      setState(() => message = ex.toString());
    } finally {
      if (!silent && mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = status['connected'] == true;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: AppSurfaces.panel(radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ClawEmail',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              StatusPill(
                label: connected ? '已绑定' : '未绑定',
                color: connected ? LinearColors.green : LinearColors.amber,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            connected
                ? '${status['userEmail'] ?? ''} · ${status['domain'] ?? 'claw.163.com'}'
                : '绑定 Claw 后可同步子邮箱和通讯规则。',
            style: AppText.muted,
          ),
          const SizedBox(height: 22),
          TextField(
            controller: email,
            decoration: const InputDecoration(labelText: 'Claw 登录邮箱'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: '验证码'),
                ),
              ),
              const SizedBox(width: 12),
              LinearButton(
                label: '发送验证码',
                onPressed: busy
                    ? null
                    : () => _run(
                        () => widget.state.api!.clawSendCode(email.text),
                        '验证码已发送',
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              LinearButton(
                label: '绑定并同步',
                icon: Icons.sync,
                primary: true,
                onPressed: busy
                    ? null
                    : () => _run(
                        () => widget.state.api!.clawVerifyCode(
                          email.text,
                          code.text,
                        ),
                        'Claw 已绑定并同步',
                      ),
              ),
              const SizedBox(width: 12),
              LinearButton(
                label: '刷新授权',
                icon: Icons.refresh,
                onPressed: busy
                    ? null
                    : () =>
                          _run(widget.state.api!.clawRefreshAuth, 'Claw 授权已刷新'),
              ),
            ],
          ),
          const Divider(height: 34),
          _MailboxCreator(
            controller: suffix,
            busy: busy,
            onCreate: () => _run(
              () => widget.state.api!.clawCreateMailbox(suffix.text),
              '子邮箱已创建',
            ),
            onSync: () => _run(
              () => widget.state.api!
                  .clawMailboxes(sync: true)
                  .then((items) => mailboxes = items),
              '子邮箱已同步',
            ),
          ),
          const SizedBox(height: 14),
          Expanded(child: _MailboxList(items: mailboxes)),
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(message, style: AppText.muted),
            ),
        ],
      ),
    );
  }
}

class _MailboxCreator extends StatelessWidget {
  const _MailboxCreator({
    required this.controller,
    required this.busy,
    required this.onCreate,
    required this.onSync,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '新子邮箱后缀'),
          ),
        ),
        const SizedBox(width: 12),
        LinearButton(label: '创建', onPressed: busy ? null : onCreate),
        const SizedBox(width: 8),
        LinearButton(label: '同步', onPressed: busy ? null : onSync),
      ],
    );
  }
}

class _MailboxList extends StatelessWidget {
  const _MailboxList({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('暂无 Claw 子邮箱', style: AppText.muted));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LinearColors.panel.withValues(alpha: .76),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: LinearColors.chromeLine.withValues(alpha: .62),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['email']?.toString() ?? '', style: AppText.itemTitle),
              const SizedBox(height: 4),
              Text(
                '${item['status'] ?? ''} · ${item['mailbox_type'] ?? ''}',
                style: AppText.caption,
              ),
            ],
          ),
        );
      },
    );
  }
}
