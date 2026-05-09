import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import 'workspace_top_bar_controls.dart';

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
                WorkspacePageGlyph(icon: _pageIcon(state.page)),
                const SizedBox(width: 14),
              ],
              Expanded(child: _TitleBlock(state: state)),
              const SizedBox(width: 12),
              Flexible(
                flex: isTight ? 0 : 1,
                child: WorkspaceHeaderTools(
                  children: [
                    WorkspaceTopAction(state: state),
                    if (showLifecycle) TopBarStatusItems.lifecycle(state),
                    if (showMode) WorkspaceModeSwitch(state: state),
                    if (showServer)
                      TopBarStatusItems.server(_serverLabel(state.serverUrl)),
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
