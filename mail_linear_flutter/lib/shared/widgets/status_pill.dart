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
  });

  final String label;
  final Color color;
  final IconData? icon;
  final double? maxWidth;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: MotionTokens.duration(context, MotionTokens.normal),
      curve: MotionTokens.easeOut,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .22)),
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
                style: AppText.label.copyWith(color: color),
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
