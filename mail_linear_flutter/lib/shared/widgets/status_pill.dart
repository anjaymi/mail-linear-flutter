import 'package:flutter/material.dart';

import '../../core/motion/motion_tokens.dart';
import '../../core/theme/app_theme.dart';
import 'motion_widgets.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.color = LinearColors.green,
    this.icon,
    this.maxWidth,
    this.busy = false,
    this.solid = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final double? maxWidth;
  final bool busy;

  /// When `true`, pill renders with a tinted background (strong signal).
  /// Default `false` — soft pill with transparent bg + neutral border +
  /// colored dot + muted text. Reserve `solid` for error/warning/busy.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: MotionTokens.duration(context, MotionTokens.normal),
      curve: MotionTokens.easeOut,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: solid ? color.withValues(alpha: .1) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.xs),
        border: Border.all(
          color: solid ? color.withValues(alpha: .22) : LinearColors.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon == null
              ? Icon(Icons.circle, size: 8, color: color)
              : MotionSyncIcon(
                  icon: icon!,
                  active: busy,
                  size: 16,
                  color: color,
                ),
          const SizedBox(width: 8),
          Flexible(
            child: AnimatedSwitcher(
              duration: MotionTokens.duration(context, MotionTokens.normal),
              switchInCurve: MotionTokens.easeOut,
              switchOutCurve: Curves.easeIn,
              child: Text(
                label,
                key: ValueKey(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label.copyWith(
                  color: solid ? color : LinearColors.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (maxWidth == null) return content;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: content,
    );
  }
}
