import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import 'vector_chrome_icons.dart';

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 226,
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: AppSurfaces.chrome(radius: 26),
      child: Column(
        children: [
          const _Brand(),
          const SizedBox(height: 30),
          _NavItem(
            Icons.space_dashboard_outlined,
            '工作台',
            AppPage.dashboard,
            state,
          ),
          _NavItem(Icons.alternate_email, '账号', AppPage.accounts, state),
          _NavItem(Icons.mail_outline, '邮件', AppPage.mail, state),
          if (state.mode == WorkMode.claw)
            _NavItem(Icons.hub_outlined, 'Claw', AppPage.claw, state),
          _NavItem(Icons.tune, '设置', AppPage.settings, state),
          const Spacer(),
          _RuntimeBadge(mode: state.mode),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: LinearColors.blue,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: LinearColors.blue.withValues(alpha: .28),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: const Center(
            child: MailLogoGlyph(color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '邮箱工作台',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sectionTitle,
              ),
              const SizedBox(height: 2),
              Text(
                'Outlook / Claw',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(this.icon, this.label, this.page, this.state);

  final IconData icon;
  final String label;
  final AppPage page;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final active = state.page == page;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => state.setPage(page),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active
                  ? LinearColors.blue.withValues(alpha: .10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: active
                    ? LinearColors.blue.withValues(alpha: .08)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 4,
                  height: active ? 20 : 4,
                  decoration: BoxDecoration(
                    color: active ? LinearColors.blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 10),
                _IconTile(icon: icon, active: active),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: AppText.bodyStrong.copyWith(
                    color: active ? LinearColors.blue : LinearColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: active
            ? Colors.transparent
            : LinearColors.surfaceSoft.withValues(alpha: .80),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        icon,
        size: 16,
        color: active ? LinearColors.blue : LinearColors.muted,
      ),
    );
  }
}

class _RuntimeBadge extends StatelessWidget {
  const _RuntimeBadge({required this.mode});

  final WorkMode mode;

  @override
  Widget build(BuildContext context) {
    final title = mode == WorkMode.claw ? 'Claw 通道' : 'Outlook 通道';
    final detail = mode == WorkMode.claw ? '子邮箱与通讯规则' : '令牌收件与缓存';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LinearColors.panel.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: LinearColors.chromeLine.withValues(alpha: .58),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: LinearColors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(title, style: AppText.bodyStrong),
            ],
          ),
          const SizedBox(height: 8),
          Text(detail, style: AppText.caption),
        ],
      ),
    );
  }
}
