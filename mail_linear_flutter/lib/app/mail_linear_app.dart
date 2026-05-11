import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
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
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => MaterialApp(
        title: state.text.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: state.language.locale,
        supportedLocales: AppLanguage.values.map((item) => item.locale),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: LinearShell(state: state, child: _page()),
      ),
    );
  }

  Widget _page() {
    if (state.loading) return const _BootPage();
    return switch (state.page) {
      AppPage.mail => MailPage(state: state),
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
