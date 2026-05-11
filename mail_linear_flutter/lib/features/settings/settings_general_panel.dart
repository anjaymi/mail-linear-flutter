part of 'settings_page.dart';

class _GeneralPanel extends StatelessWidget {
  const _GeneralPanel({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          _SettingRow(
            title: state.text.languageTitle,
            detail: state.text.languageDetail,
            trailing: _LanguageControls(state: state),
          ),
          _SettingRow(
            title: state.text.ui('主题色'),
            detail: state.text.ui('更改按钮和强调色'),
            trailing: _AccentColorPicker(state: state),
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
            showDivider: false,
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
    this.showDivider = true,
  });
  final String title;
  final String detail;
  final Widget trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: LinearColors.line))
            : null,
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
          const SizedBox(width: 16),
          SizedBox(
            width: 300,
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing,
            ),
          ),
        ],
      ),
    );
  }
}
