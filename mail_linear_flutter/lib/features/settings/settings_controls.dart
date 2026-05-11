part of 'settings_page.dart';

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
      child: _PickerShell(
        width: 174,
        enabled: true,
        child: Text(
          state.language.nativeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.bodyStrong,
        ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Transform.scale(
          scale: .9,
          child: Switch(
            value: state.autoReceiveEnabled,
            onChanged: state.setAutoReceiveEnabled,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
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
          child: _PickerShell(
            width: 112,
            enabled: state.autoReceiveEnabled,
            child: Text(
              state.text.minutes(state.autoReceiveMinutes),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyStrong,
            ),
          ),
        ),
      ],
    );
  }
}

class _SoundControls extends StatelessWidget {
  const _SoundControls({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final current = SoundService.optionOf(state.soundTone);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Transform.scale(
          scale: .9,
          child: Switch(
            value: state.soundEnabled,
            onChanged: state.setSoundEnabled,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
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
          child: _PickerShell(
            width: 160,
            enabled: state.soundEnabled,
            child: Text(
              state.text.soundLabel(current.value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyStrong,
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: state.text.preview,
          onPressed: state.soundEnabled ? state.previewSound : null,
          icon: const Icon(Icons.play_arrow_rounded),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        ),
      ],
    );
  }
}

class _PickerShell extends StatelessWidget {
  const _PickerShell({required this.enabled, required this.child, this.width});

  final bool enabled;
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? LinearColors.ink : LinearColors.faint;
    return Container(
      height: 42,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? LinearColors.surface : LinearColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: enabled ? LinearColors.line : LinearColors.chromeLine,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg),
        child: Row(
          children: [
            Expanded(child: child),
            const SizedBox(width: 6),
            Icon(
              Icons.expand_more,
              size: 18,
              color: enabled ? LinearColors.muted : LinearColors.faint,
            ),
          ],
        ),
      ),
    );
  }
}


class _AccentColorPicker extends StatelessWidget {
  const _AccentColorPicker({required this.state});
  final AppState state;

  static const _presets = [
    ('黑', Color(0xff1b1b1f)),
    ('蓝', Color(0xff2e4bd8)),
    ('靛', Color(0xff5e6ad2)),
    ('绿', Color(0xff18b981)),
    ('红', Color(0xffef4444)),
    ('橙', Color(0xfff59e0b)),
    ('紫', Color(0xff7c3aed)),
    ('青', Color(0xff0ea5e9)),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (label, color) in _presets)
          _ColorDot(
            color: color,
            selected: state.accentColor.toARGB32() == color.toARGB32(),
            tooltip: state.text.ui(label),
            onTap: () => state.setAccentColor(color),
          ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });
  final Color color;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(color: LinearColors.ink, width: 2.5)
                : Border.all(color: color.withValues(alpha: .3), width: 1),
          ),
          child: selected
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
