import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/platform/sound_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/status_pill.dart';
import 'claw_settings_panel.dart';
import 'database_panel.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.state, this.clawOnly = false});

  final AppState state;
  final bool clawOnly;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: clawOnly
              ? ClawSettingsPanel(state: state)
              : _GeneralPanel(state: state),
        ),
        const SizedBox(width: 22),
        SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _ServerPanel(state: state),
                if (!clawOnly) ...[
                  const SizedBox(height: 18),
                  DatabasePanel(state: state),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GeneralPanel extends StatelessWidget {
  const _GeneralPanel({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: AppSurfaces.panel(radius: 28),
      child: Column(
        children: [
          _SettingRow(
            title: state.text.languageTitle,
            detail: state.text.languageDetail,
            trailing: _LanguageControls(state: state),
          ),
          _SettingRow(
            title: state.text.autoStartTitle,
            detail: state.text.autoStartDetail,
            trailing: StatusPill(label: state.text.enabled),
          ),
          _SettingRow(
            title: state.text.autoReceiveTitle,
            detail: state.text.autoReceiveDetail,
            trailing: _AutoReceiveControls(state: state),
          ),
          _SettingRow(
            title: state.text.portPolicyTitle,
            detail: state.text.portPolicyDetail,
            trailing: StatusPill(label: state.text.autoSwitch),
          ),
          _SettingRow(
            title: state.text.soundTitle,
            detail: state.text.soundDetail,
            trailing: _SoundControls(state: state),
          ),
        ],
      ),
    );
  }
}

class _ServerPanel extends StatelessWidget {
  const _ServerPanel({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppSurfaces.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.text.localApiEngine,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          StatusPill(
            label: state.serverUrl.replaceFirst('http://', ''),
            icon: Icons.cloud_done_outlined,
          ),
          const SizedBox(height: 16),
          Text(state.text.apiEngineDetail, style: AppText.muted),
          const SizedBox(height: 24),
          LinearButton(
            label: state.text.testConnection,
            icon: Icons.bolt_outlined,
            primary: true,
            onPressed: state.refresh,
          ),
        ],
      ),
    );
  }
}

class _LanguageControls extends StatelessWidget {
  const _LanguageControls({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppLanguage>(
      tooltip: state.text.languageTitle,
      onSelected: state.setLanguage,
      itemBuilder: (context) => [
        for (final language in AppLanguage.values)
          PopupMenuItem(
            value: language,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: state.language == language
                      ? const Icon(Icons.check, size: 17)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(language.nativeName, style: AppText.bodyStrong),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 42,
        width: 174,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: LinearColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LinearColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                state.language.nativeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong,
              ),
            ),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.detail,
    required this.trailing,
  });
  final String title;
  final String detail;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LinearColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.itemTitle),
                const SizedBox(height: 6),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.muted,
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _AutoReceiveControls extends StatelessWidget {
  const _AutoReceiveControls({required this.state});

  static const _minutes = [1, 3, 5, 10, 15, 30];

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Switch(
            value: state.autoReceiveEnabled,
            onChanged: state.setAutoReceiveEnabled,
          ),
          const SizedBox(width: 8),
          PopupMenuButton<int>(
            enabled: state.autoReceiveEnabled,
            tooltip: state.text.autoReceiveInterval,
            onSelected: state.setAutoReceiveMinutes,
            itemBuilder: (context) => [
              for (final minute in _minutes)
                PopupMenuItem(
                  value: minute,
                  child: Text(
                    state.text.minutes(minute),
                    style: AppText.bodyStrong,
                  ),
                ),
            ],
            child: Container(
              height: 42,
              width: 112,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: state.autoReceiveEnabled
                    ? LinearColors.surface
                    : LinearColors.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LinearColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.text.minutes(state.autoReceiveMinutes),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong,
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundControls extends StatelessWidget {
  const _SoundControls({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final current = SoundService.optionOf(state.soundTone);
    return SizedBox(
      width: 250,
      child: Row(
        children: [
          Switch(value: state.soundEnabled, onChanged: state.setSoundEnabled),
          const SizedBox(width: 8),
          Expanded(
            child: PopupMenuButton<String>(
              enabled: state.soundEnabled,
              tooltip: state.text.selectSound,
              onSelected: state.setSoundTone,
              itemBuilder: (context) => [
                for (final option in SoundService.options)
                  PopupMenuItem(
                    value: option.value,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.text.soundLabel(option.value),
                          style: AppText.bodyStrong,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.text.soundDescription(option.value),
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
              ],
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: state.soundEnabled
                      ? LinearColors.surface
                      : LinearColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: LinearColors.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.text.soundLabel(current.value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong,
                      ),
                    ),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: state.text.preview,
            onPressed: state.soundEnabled ? state.previewSound : null,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }
}
