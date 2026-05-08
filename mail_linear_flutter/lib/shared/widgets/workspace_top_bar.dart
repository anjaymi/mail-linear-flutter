import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import 'lifecycle_pill.dart';
import 'status_pill.dart';
import 'vector_chrome_icons.dart';

class WorkspaceTopBar extends StatelessWidget {
  const WorkspaceTopBar({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isTight = width < 540;
        final showLifecycle = width >= 700;
        final showMode = width >= 820;
        final showServer = width >= 1040;

        return SizedBox(
          height: 66,
          child: Row(
            children: [
              if (!isTight) ...[
                _PageGlyph(icon: _pageIcon(state.page)),
                const SizedBox(width: 14),
              ],
              Expanded(child: _TitleBlock(state: state)),
              const SizedBox(width: 12),
              Flexible(
                flex: isTight ? 0 : 1,
                child: _HeaderTools(
                  children: [
                    _TopAction(state: state),
                    if (showLifecycle) LifecyclePill(state: state),
                    if (showMode) _ModeSwitch(state: state),
                    if (showServer)
                      StatusPill(
                        label: _serverLabel(state.serverUrl),
                        icon: Icons.cloud_done_outlined,
                        maxWidth: 150,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _pageIcon(AppPage page) => switch (page) {
    AppPage.dashboard => Icons.space_dashboard_outlined,
    AppPage.accounts => Icons.alternate_email,
    AppPage.mail => Icons.mail_outline,
    AppPage.claw => Icons.hub_outlined,
    AppPage.settings => Icons.tune,
  };

  String _serverLabel(String url) =>
      url.replaceFirst('http://', '').replaceFirst('https://', '');
}

class _HeaderTools extends StatelessWidget {
  const _HeaderTools({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: LinearColors.chrome.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: LinearColors.chromeLine.withValues(alpha: .7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 3),
        Text(
          _subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.muted,
        ),
      ],
    );
  }

  String get _title => switch (state.page) {
    AppPage.dashboard => state.text.dashboard,
    AppPage.accounts => state.text.accounts,
    AppPage.mail => state.text.mail,
    AppPage.claw => state.text.clawSettings,
    AppPage.settings => state.text.settings,
  };

  String get _subtitle => switch (state.page) {
    AppPage.dashboard => state.text.dashboardSubtitle,
    AppPage.accounts => state.text.accountsSubtitle,
    AppPage.mail => state.text.mailSubtitle,
    AppPage.claw => state.text.clawSubtitle,
    AppPage.settings => state.text.settingsSubtitle,
  };
}

class _TopAction extends StatelessWidget {
  const _TopAction({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final action = _ActionSpec.from(state);
    return MouseRegion(
      cursor: action.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: FilledButton.icon(
        onPressed: action.onTap,
        icon: Icon(action.icon, size: 17),
        label: Text(action.label),
        style: FilledButton.styleFrom(
          backgroundColor: action.primary
              ? LinearColors.ink
              : LinearColors.panel,
          foregroundColor: action.primary ? Colors.white : LinearColors.ink,
          disabledBackgroundColor: LinearColors.surfaceSoft,
          disabledForegroundColor: LinearColors.faint,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: action.primary ? Colors.transparent : LinearColors.line,
            ),
          ),
          textStyle: AppText.control,
        ),
      ),
    );
  }
}

class _ActionSpec {
  const _ActionSpec({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  factory _ActionSpec.from(AppState state) {
    final canReceive = state.mode == WorkMode.claw
        ? state.selectedClawMailbox != null
        : state.selectedAccount != null;
    return switch (state.page) {
      AppPage.dashboard => _ActionSpec(
        label: state.mode == WorkMode.claw
            ? state.fetching
                  ? state.text.fetching
                  : state.text.clawFetch
            : state.fetching
            ? state.text.fetching
            : state.text.startFetch,
        icon: Icons.sync,
        primary: true,
        onTap: state.fetching || !canReceive ? null : state.fetchSelectedMail,
      ),
      AppPage.accounts => _ActionSpec(
        label: state.text.refreshAccounts,
        icon: Icons.refresh,
        onTap: state.refresh,
      ),
      AppPage.mail => _ActionSpec(
        label: state.fetching ? state.text.syncing : state.text.fetchLatest,
        icon: Icons.mark_email_unread_outlined,
        primary: true,
        onTap: state.fetching || !canReceive ? null : state.fetchSelectedMail,
      ),
      AppPage.claw => _ActionSpec(
        label: state.text.syncClaw,
        icon: Icons.sync_alt,
        onTap: state.refresh,
      ),
      AppPage.settings => _ActionSpec(
        label: state.text.testConnection,
        icon: Icons.cable_outlined,
        onTap: state.refresh,
      ),
    };
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LinearColors.surfaceSoft.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: LinearColors.chromeLine.withValues(alpha: .62),
        ),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: 'Outlook',
            selected: state.mode == WorkMode.outlook,
            onTap: () => state.setMode(WorkMode.outlook),
          ),
          _ModeButton(
            label: 'Claw',
            selected: state.mode == WorkMode.claw,
            onTap: () => state.setMode(WorkMode.claw),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? LinearColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: AppText.label.copyWith(
              color: selected ? Colors.white : LinearColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageGlyph extends StatelessWidget {
  const _PageGlyph({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: LinearColors.blue,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: LinearColors.blue.withValues(alpha: .18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: icon == Icons.mail_outline
            ? const MailLogoGlyph(color: Colors.white, size: 22)
            : Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
