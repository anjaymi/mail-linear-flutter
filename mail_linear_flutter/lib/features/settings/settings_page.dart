import 'package:flutter/material.dart';

import '../../app/app_state.dart';
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
          const _SettingRow(
            title: '界面语言',
            detail: '桌面端主要界面文字。',
            trailing: StatusPill(label: '中文'),
          ),
          const _SettingRow(
            title: '自动启动',
            detail: '打开 EXE 后自动创建本地 API 端口。',
            trailing: StatusPill(label: '已开启'),
          ),
          _SettingRow(
            title: '自动接收',
            detail: '按间隔自动收取当前选中的 Outlook 账号。',
            trailing: _AutoReceiveControls(state: state),
          ),
          const _SettingRow(
            title: '端口策略',
            detail: '3000 被占用时改用下一个可用端口。',
            trailing: StatusPill(label: '自动切换'),
          ),
          _SettingRow(
            title: '声音提示',
            detail: '新邮件到达时播放提醒，可选择提示音。',
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
          Text('本地 API 引擎', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          StatusPill(
            label: state.serverUrl.replaceFirst('http://', ''),
            icon: Icons.cloud_done_outlined,
          ),
          const SizedBox(height: 16),
          const Text(
            'Flutter 只负责桌面 UI，收件、数据库和 Claw 适配继续由 Rust sidecar 处理。',
            style: AppText.muted,
          ),
          const SizedBox(height: 24),
          LinearButton(
            label: '测试连接',
            icon: Icons.bolt_outlined,
            primary: true,
            onPressed: state.refresh,
          ),
        ],
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
            tooltip: '自动接收间隔',
            onSelected: state.setAutoReceiveMinutes,
            itemBuilder: (context) => [
              for (final minute in _minutes)
                PopupMenuItem(
                  value: minute,
                  child: Text('$minute 分钟', style: AppText.bodyStrong),
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
                      '${state.autoReceiveMinutes} 分钟',
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
              tooltip: '选择提示音',
              onSelected: state.setSoundTone,
              itemBuilder: (context) => [
                for (final option in SoundService.options)
                  PopupMenuItem(
                    value: option.value,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(option.label, style: AppText.bodyStrong),
                        const SizedBox(height: 2),
                        Text(option.description, style: AppText.caption),
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
                        current.label,
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
            tooltip: '试听',
            onPressed: state.soundEnabled ? state.previewSound : null,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }
}
