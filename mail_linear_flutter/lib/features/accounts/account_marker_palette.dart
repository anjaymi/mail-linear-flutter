import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/motion/motion_tokens.dart';
import '../../core/theme/app_theme.dart';

class MarkerOption {
  const MarkerOption(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;
}

const markerOptions = [
  MarkerOption('蓝', '#3b6df6', Color(0xff3b6df6)),
  MarkerOption('绿', '#18b981', Color(0xff18b981)),
  MarkerOption('橙', '#f59e0b', Color(0xfff59e0b)),
  MarkerOption('红', '#ef4444', Color(0xffef4444)),
  MarkerOption('紫', '#7c3aed', Color(0xff7c3aed)),
  MarkerOption('青', '#0ea5e9', Color(0xff0ea5e9)),
];

MarkerOption? markerOptionOf(String value) {
  final normalized = value.trim().toLowerCase();
  for (final option in markerOptions) {
    if (option.value.toLowerCase() == normalized) return option;
  }
  return null;
}

class AccountMarkerPalette extends StatelessWidget {
  const AccountMarkerPalette({
    super.key,
    required this.state,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final AppState state;
  final String value;
  final ValueChanged<String> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final selected = markerOptionOf(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Text(
            state.text.ui('账号标记'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: compact ? 6 : 8,
          runSpacing: 8,
          children: [
            for (final option in markerOptions)
              _Swatch(
                option: option,
                state: state,
                selected: selected?.value == option.value,
                compact: compact,
                onTap: () => onChanged(option.value),
              ),
            _ClearSwatch(
              state: state,
              onTap: () => onChanged(''),
              compact: compact,
            ),
          ],
        ),
      ],
    );
  }
}

class MarkerLabel extends StatelessWidget {
  const MarkerLabel({super.key, required this.state, required this.value});

  final AppState state;
  final String value;

  @override
  Widget build(BuildContext context) {
    final option = markerOptionOf(value);
    if (option == null) {
      return AnimatedSwitcher(
        duration: MotionTokens.duration(context, MotionTokens.normal),
        child: Text(
          state.text.ui('未标记'),
          key: const ValueKey('marker-empty'),
          style: AppText.caption,
        ),
      );
    }
    return AnimatedSwitcher(
      duration: MotionTokens.duration(context, MotionTokens.normal),
      child: Row(
        key: ValueKey(option.value),
        children: [
          AnimatedContainer(
            duration: MotionTokens.duration(context, MotionTokens.normal),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: option.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.text.colorLabel(option.label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class MarkerPaletteButton extends StatelessWidget {
  const MarkerPaletteButton({
    super.key,
    required this.state,
    required this.value,
    required this.onChanged,
  });

  final AppState state;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: state.text.ui('标记颜色'),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in markerOptions)
          PopupMenuItem(
            value: option.value,
            child: Row(
              children: [
                _ColorDot(color: option.color),
                const SizedBox(width: 10),
                Text(state.text.colorMarker(option.label)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(value: '', child: Text(state.text.ui('清除标记'))),
      ],
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LinearColors.panel.withValues(alpha: .72),
          shape: BoxShape.circle,
          border: Border.all(color: LinearColors.line),
        ),
        child: Icon(
          Icons.palette_outlined,
          color: markerOptionOf(value)?.color ?? LinearColors.muted,
          size: 18,
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.option,
    required this.state,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final MarkerOption option;
  final AppState state;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 34.0;
    return Tooltip(
      message: state.text.colorMarker(option.label),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.04 : 1,
          duration: MotionTokens.duration(context, MotionTokens.fast),
          curve: MotionTokens.easeOut,
          child: AnimatedContainer(
            duration: MotionTokens.duration(context, MotionTokens.fast),
            curve: MotionTokens.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: option.color.withValues(alpha: selected ? 1 : .16),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? option.color
                    : option.color.withValues(alpha: .3),
                width: selected ? 2.4 : 1,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

class _ClearSwatch extends StatelessWidget {
  const _ClearSwatch({
    required this.state,
    required this.onTap,
    required this.compact,
  });

  final AppState state;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: state.text.ui('清除标记'),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: compact ? 28 : 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: LinearColors.surfaceSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: LinearColors.line),
          ),
          child: Text(state.text.ui('清除'), style: AppText.label),
        ),
      ),
    );
  }
}
