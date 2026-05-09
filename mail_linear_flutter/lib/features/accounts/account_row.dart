import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/motion/motion_tokens.dart';
import '../../core/models/mail_account.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/motion_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import 'account_marker_palette.dart';

class AccountRow extends StatelessWidget {
  const AccountRow({
    super.key,
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
    return MotionTapSurface(
      lift: false,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: MotionTokens.duration(context, MotionTokens.normal),
          curve: MotionTokens.easeOut,
          height: 66,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
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
              SizedBox(
                width: 34,
                child: Checkbox(
                  value: checked,
                  onChanged: (v) => onCheck(v ?? false),
                ),
              ),
              const SizedBox(width: 8),
              _MarkerStrip(color: account.color),
              const SizedBox(width: 12),
              Expanded(
                child: _AccountIdentity(state: state, account: account),
              ),
              SizedBox(
                width: 78,
                child: MarkerLabel(state: state, value: account.markerColor),
              ),
              SizedBox(
                width: 82,
                child: StatusPill(
                  label: state.text.ui(account.isError ? '异常' : '可用'),
                  color: account.isError
                      ? LinearColors.red
                      : LinearColors.green,
                ),
              ),
              SizedBox(
                width: 142,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MarkerPaletteButton(
                      state: state,
                      value: account.markerColor,
                      onChanged: onMarker,
                    ),
                    _RowIconButton(
                      tooltip: state.text.ui('复制邮箱'),
                      onPressed: () => _copyAccount(context, account),
                      icon: Icons.copy,
                    ),
                    _RowIconButton(
                      tooltip: state.text.ui('打开该账号邮件'),
                      onPressed: onTap,
                      icon: Icons.mail_outline,
                    ),
                    _RowIconButton(
                      tooltip: state.text.ui('删除'),
                      onPressed: onDelete,
                      icon: Icons.close,
                      color: LinearColors.red,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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

class _AccountIdentity extends StatelessWidget {
  const _AccountIdentity({required this.state, required this.account});
  final AppState state;
  final MailAccount account;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          account.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.itemTitle,
        ),
        const SizedBox(height: 4),
        Text(
          account.lastSyncedAt.isEmpty
              ? state.text.ui('等待同步')
              : '${state.text.ui('已刷新')} ${account.lastSyncedAt}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption,
        ),
      ],
    );
  }
}

class _RowIconButton extends StatelessWidget {
  const _RowIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.color = LinearColors.ink,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MotionTapSurface(
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 34),
        icon: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _MarkerStrip extends StatelessWidget {
  const _MarkerStrip({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MotionTokens.duration(context, MotionTokens.normal),
      curve: MotionTokens.easeOut,
      width: 5,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
