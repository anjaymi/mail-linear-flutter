import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/motion_tokens.dart';
import '../../core/theme/app_theme.dart';

class MotionTapSurface extends StatefulWidget {
  const MotionTapSurface({
    super.key,
    required this.child,
    this.enabled = true,
    this.lift = true,
  });

  final Widget child;
  final bool enabled;
  final bool lift;

  @override
  State<MotionTapSurface> createState() => _MotionTapSurfaceState();
}

class _MotionTapSurfaceState extends State<MotionTapSurface> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final scale = !enabled
        ? 1.0
        : _pressed
        ? MotionTokens.pressScale(context)
        : _hovered
        ? MotionTokens.hoverScale(context)
        : 1.0;
    final shadow = enabled && widget.lift && _hovered && !_pressed;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) {
          if (enabled) setState(() => _pressed = true);
        },
        onPointerCancel: (_) => setState(() => _pressed = false),
        onPointerUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          duration: MotionTokens.duration(context, MotionTokens.fast),
          curve: MotionTokens.easeOutStrong,
          scale: scale,
          child: AnimatedContainer(
            duration: MotionTokens.duration(context, MotionTokens.normal),
            curve: MotionTokens.easeOut,
            decoration: BoxDecoration(
              boxShadow: shadow
                  ? [
                      BoxShadow(
                        color: LinearColors.ink.withValues(alpha: .055),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class MotionIconTile extends StatelessWidget {
  const MotionIconTile({
    super.key,
    required this.icon,
    required this.active,
    this.size = 28,
    this.iconSize = 16,
    this.activeColor = LinearColors.blue,
    this.inactiveColor = LinearColors.muted,
  });

  final IconData icon;
  final bool active;
  final double size;
  final double iconSize;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final duration = MotionTokens.duration(context, MotionTokens.normal);
    return AnimatedContainer(
      width: size,
      height: size,
      duration: duration,
      curve: MotionTokens.easeOut,
      decoration: BoxDecoration(
        color: active
            ? activeColor.withValues(alpha: .12)
            : LinearColors.surfaceSoft.withValues(alpha: .80),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: AnimatedScale(
        scale: active ? 1.04 : 1,
        duration: duration,
        curve: MotionTokens.easeOutStrong,
        child: Icon(
          icon,
          size: iconSize,
          color: active ? activeColor : inactiveColor,
        ),
      ),
    );
  }
}

class MotionSyncIcon extends StatefulWidget {
  const MotionSyncIcon({
    super.key,
    required this.icon,
    required this.active,
    this.size = 18,
    this.color,
  });

  final IconData icon;
  final bool active;
  final double size;
  final Color? color;

  @override
  State<MotionSyncIcon> createState() => _MotionSyncIconState();
}

class _MotionSyncIconState extends State<MotionSyncIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant MotionSyncIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active && !MotionTokens.reduced(context)) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: Icon(widget.icon, size: widget.size, color: widget.color),
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * math.pi * 2,
          child: child,
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
