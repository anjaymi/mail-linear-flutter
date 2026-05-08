import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class LinearButton extends StatelessWidget {
  const LinearButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? LinearColors.blue : Colors.white;
    final fg = primary ? Colors.white : LinearColors.ink;
    return FilledButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: LinearColors.surfaceSoft,
        disabledForegroundColor: LinearColors.faint,
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
    );
  }
}
