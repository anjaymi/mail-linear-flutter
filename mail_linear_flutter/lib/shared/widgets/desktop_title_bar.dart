import 'package:flutter/material.dart';

import '../../core/platform/window_controls.dart';
import '../../core/theme/app_theme.dart';
import 'vector_chrome_icons.dart';

class DesktopTitleBar extends StatelessWidget {
  const DesktopTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => WindowControls.drag(),
              onDoubleTap: WindowControls.toggleMaximize,
              child: const SizedBox.expand(),
            ),
          ),
          const _WindowButton(
            type: WindowGlyphType.minimize,
            onPressed: WindowControls.minimize,
          ),
          const _WindowButton(
            type: WindowGlyphType.maximize,
            onPressed: WindowControls.toggleMaximize,
          ),
          const _WindowButton(
            type: WindowGlyphType.close,
            danger: true,
            onPressed: WindowControls.close,
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.type,
    required this.onPressed,
    this.danger = false,
  });

  final WindowGlyphType type;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? LinearColors.red : LinearColors.muted;
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          hoverColor: (danger ? LinearColors.red : LinearColors.blue)
              .withValues(alpha: .10),
          onTap: onPressed,
          child: SizedBox(
            width: 30,
            height: 28,
            child: Center(
              child: WindowChromeGlyph(type: type, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
