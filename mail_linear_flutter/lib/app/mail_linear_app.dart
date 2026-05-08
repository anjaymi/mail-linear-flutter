import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/accounts/accounts_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/mail/mail_page.dart';
import '../features/settings/settings_page.dart';
import '../shared/widgets/linear_shell.dart';
import 'app_state.dart';

class MailLinearApp extends StatefulWidget {
  const MailLinearApp({super.key});

  @override
  State<MailLinearApp> createState() => _MailLinearAppState();
}

class _MailLinearAppState extends State<MailLinearApp> {
  late final AppState state;

  @override
  void initState() {
    super.initState();
    state = AppState()..boot();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mail Workspace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AnimatedBuilder(
        animation: state,
        builder: (context, _) => LinearShell(state: state, child: _page()),
      ),
    );
  }

  Widget _page() {
    if (state.loading) return const _BootPage();
    return switch (state.page) {
      AppPage.dashboard => DashboardPage(state: state),
      AppPage.accounts => AccountsPage(state: state),
      AppPage.mail => MailPage(state: state),
      AppPage.claw => SettingsPage(state: state, clawOnly: true),
      AppPage.settings => SettingsPage(state: state),
    };
  }
}

class _BootPage extends StatelessWidget {
  const _BootPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}
