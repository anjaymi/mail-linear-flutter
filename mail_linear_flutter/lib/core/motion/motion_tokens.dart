import 'package:flutter/material.dart';

abstract final class MotionTokens {
  static const fast = Duration(milliseconds: 110);
  static const normal = Duration(milliseconds: 180);
  static const page = Duration(milliseconds: 260);

  static const easeOut = Cubic(0.25, 1, 0.5, 1);
  static const easeOutStrong = Cubic(0.22, 1, 0.36, 1);

  static bool reduced(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static Duration duration(BuildContext context, Duration value) {
    return reduced(context) ? Duration.zero : value;
  }

  static double hoverScale(BuildContext context) =>
      reduced(context) ? 1 : 1.015;

  static double pressScale(BuildContext context) => reduced(context) ? 1 : .975;
}
