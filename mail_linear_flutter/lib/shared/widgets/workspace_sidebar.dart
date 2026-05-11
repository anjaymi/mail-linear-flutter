import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/models/mail_account.dart';
import '../../core/theme/app_theme.dart';
import 'motion_widgets.dart';

/// ProMail-style sidebar: logo + nav (Inbox/Sent/Drafts/Trash) +
/// ACCOUNTS section with avatar rows + Settings/Support at bottom.
class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        color: LinearColors.surface,
        border: Border(
          right: BorderSide(color: LinearColors.line, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── brand ──
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 20),
            child: Text(
              state.text.workspace,
              style: AppText.sectionTitle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // ── primary action ──
          SizedBox(
            width: double.infinity,
            height: 36,
            child: _ComposeButton(state: state),
          ),
          const SizedBox(height: 20),
          // ── nav ──
          _NavItem(
            icon: Icons.inbox_outlined,
            label: state.text.mail,
            badge: '${state.mails.isNotEmpty ? state.mails.length : ''}',
            active: state.page == AppPage.mail && state.mailFilter == MailFilter.all,
            onTap: () {
              state.setMailFilter(MailFilter.all);
              state.setPage(AppPage.mail);
            },
          ),
          _NavItem(
            icon: Icons.pin_outlined,
            label: state.text.ui('验证码邮件'),
            badge: '${state.filteredMails.length != state.mails.length ? state.filteredMails.length : ''}',
            active: state.page == AppPage.mail && state.mailFilter == MailFilter.codes,
            onTap: () {
              state.setMailFilter(MailFilter.codes);
              state.setPage(AppPage.mail);
            },
          ),
          const SizedBox(height: 20),
          // ── accounts section ──
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              state.text.ui('账号').toUpperCase(),
              style: AppText.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: LinearColors.faint,
              ),
            ),
          ),
          Expanded(child: _AccountList(state: state)),
          const SizedBox(height: 12),
          // ── bottom nav ──
          _NavItem(
            icon: Icons.settings_outlined,
            label: state.text.settings,
            active: state.page == AppPage.settings,
            onTap: () => state.setPage(AppPage.settings),
          ),
        ],
      ),
    );
  }
}

class _ComposeButton extends StatelessWidget {
  const _ComposeButton({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: state.fetching ? null : state.fetchSelectedMail,
      icon: Icon(
        state.fetching ? Icons.sync : Icons.edit_outlined,
        size: 16,
      ),
      label: Text(
        state.fetching ? state.text.fetching : state.text.ui('收取邮件'),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: state.accentColor,
        foregroundColor: LinearColors.surface,
        disabledBackgroundColor: LinearColors.surfaceSoft,
        disabledForegroundColor: LinearColors.faint,
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        textStyle: AppText.bodyStrong.copyWith(fontSize: 13),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return MotionTapSurface(
      lift: false,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? LinearColors.surfaceSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? LinearColors.ink : LinearColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? LinearColors.ink : LinearColors.muted,
                  ),
                ),
              ),
              if (badge != null && badge!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: LinearColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge!,
                    style: AppText.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: LinearColors.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountList extends StatelessWidget {
  const _AccountList({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final accounts = state.accounts;
    if (accounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 4, top: 4),
        child: Text(
          state.text.ui('尚未导入账号'),
          style: AppText.caption,
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemExtent: 44,
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        final active = state.mode == WorkMode.outlook &&
            state.selectedAccount?.id == account.id &&
            state.page == AppPage.mail;
        return _AccountRow(
          state: state,
          account: account,
          active: active,
        );
      },
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.state,
    required this.account,
    required this.active,
  });

  final AppState state;
  final MailAccount account;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final letter = account.email.isEmpty ? '?' : account.email[0].toUpperCase();
    return MotionTapSurface(
      lift: false,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: () => state.selectAccount(account),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? LinearColors.surfaceSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: account.color,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
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
                    color: active ? LinearColors.ink : LinearColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

