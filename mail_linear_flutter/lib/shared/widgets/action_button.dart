import 'package:flutter/material.dart';

import '../../core/motion/motion_tokens.dart';
import '../../core/theme/app_theme.dart';
import 'motion_widgets.dart';

class LinearButton extends StatelessWidget {
  const LinearButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? LinearColors.blue : Colors.white;
    final fg = primary ? Colors.white : LinearColors.ink;
    final enabled = onPressed != null && !busy;
    final disabledBg = busy && primary
        ? LinearColors.blue.withValues(alpha: .10)
        : LinearColors.surfaceSoft;
    final disabledFg = busy && primary ? LinearColors.blue : LinearColors.faint;

    return MotionTapSurface(
      enabled: enabled,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: _ButtonIcon(
          icon: icon,
          busy: busy,
          color: enabled ? fg : disabledFg,
        ),
        label: _AnimatedLabel(label: label),
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: disabledBg,
          disabledForegroundColor: disabledFg,
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: primary ? Colors.transparent : LinearColors.line,
            ),
          ),
          textStyle: AppText.control,
        ),
      ),
    );
  }
}

class _ButtonIcon extends StatelessWidget {
  const _ButtonIcon({
    required this.icon,
    required this.busy,
    required this.color,
  });

  final IconData? icon;
  final bool busy;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (icon == null) return const SizedBox.shrink();
    return MotionSyncIcon(icon: icon!, active: busy, size: 18, color: color);
  }
}

class _AnimatedLabel extends StatelessWidget {
  const _AnimatedLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MotionTokens.duration(context, MotionTokens.normal),
      switchInCurve: MotionTokens.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final position = Tween<Offset>(
          begin: const Offset(0, .18),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: position, child: child),
        );
      },
      child: Text(
        label,
        key: ValueKey(label),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
