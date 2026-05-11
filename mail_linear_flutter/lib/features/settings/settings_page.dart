import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/platform/sound_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/status_pill.dart';
import 'accounts_panel.dart';
import 'claw_settings_panel.dart';
import 'database_panel.dart';

part 'settings_controls.dart';
part 'settings_general_panel.dart';
part 'settings_server_panel.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 180,
          child: _SettingsNav(state: state),
        ),
        const VerticalDivider(width: 1, thickness: 0.5, color: LinearColors.line),
        Expanded(child: _SettingsContent(state: state)),
      ],
    );
  }
}

class _SettingsNav extends StatelessWidget {
  const _SettingsNav({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LinearColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 14),
            child: Text(
              state.text.settings,
              style: AppText.sectionTitle.copyWith(fontSize: 16),
            ),
          ),
          _NavTab(
            icon: Icons.tune_outlined,
            label: state.text.ui('通用'),
            active: state.settingsTab == SettingsTab.general,
            onTap: () => state.setSettingsTab(SettingsTab.general),
          ),
          _NavTab(
            icon: Icons.people_outline,
            label: state.text.ui('账号'),
            active: state.settingsTab == SettingsTab.accounts,
            onTap: () => state.setSettingsTab(SettingsTab.accounts),
          ),
          _NavTab(
            icon: Icons.hub_outlined,
            label: state.text.ui('Claw'),
            active: state.settingsTab == SettingsTab.claw,
            onTap: () => state.setSettingsTab(SettingsTab.claw),
          ),
          _NavTab(
            icon: Icons.dns_outlined,
            label: state.text.ui('服务'),
            active: state.settingsTab == SettingsTab.server,
            onTap: () => state.setSettingsTab(SettingsTab.server),
          ),
          _NavTab(
            icon: Icons.storage_outlined,
            label: state.text.ui('数据库'),
            active: state.settingsTab == SettingsTab.database,
            onTap: () => state.setSettingsTab(SettingsTab.database),
          ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          onTap: onTap,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: active ? LinearColors.surfaceSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? LinearColors.ink : LinearColors.faint,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: AppText.body.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? LinearColors.ink : LinearColors.muted,
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

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return switch (state.settingsTab) {
      SettingsTab.general => _GeneralPanel(state: state),
      SettingsTab.accounts => AccountsPanel(state: state),
      SettingsTab.claw => ClawSettingsPanel(state: state),
      SettingsTab.server => _ServerPanel(state: state),
      SettingsTab.database => DatabasePanel(state: state),
    };
  }
}
