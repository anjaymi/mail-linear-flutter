import 'package:flutter/material.dart';

enum WindowGlyphType { minimize, maximize, close }

class WindowChromeGlyph extends StatelessWidget {
  const WindowChromeGlyph({super.key, required this.type, required this.color});

  final WindowGlyphType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(14),
      painter: _WindowGlyphPainter(type: type, color: color),
    );
  }
}

class MailLogoGlyph extends StatelessWidget {
  const MailLogoGlyph({super.key, required this.color, this.size = 22});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MailLogoPainter(color: color),
    );
  }
}

class _WindowGlyphPainter extends CustomPainter {
  const _WindowGlyphPainter({required this.type, required this.color});

  final WindowGlyphType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final centerY = size.height / 2;
    switch (type) {
      case WindowGlyphType.minimize:
        canvas.drawLine(
          Offset(2.5, centerY),
          Offset(size.width - 2.5, centerY),
          paint,
        );
      case WindowGlyphType.maximize:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
            const Radius.circular(1.8),
          ),
          paint,
        );
      case WindowGlyphType.close:
        canvas
          ..drawLine(
            const Offset(3, 3),
            Offset(size.width - 3, size.height - 3),
            paint,
          )
          ..drawLine(
            Offset(size.width - 3, 3),
            Offset(3, size.height - 3),
            paint,
          );
    }
  }

  @override
  bool shouldRepaint(covariant _WindowGlyphPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}

class _MailLogoPainter extends CustomPainter {
  const _MailLogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = size.width * .08
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final rect = Rect.fromLTWH(
      size.width * .16,
      size.height * .24,
      size.width * .68,
      size.height * .52,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.width * .08)),
      stroke,
    );
    final path = Path()
      ..moveTo(rect.left + size.width * .04, rect.top + size.height * .08)
      ..lineTo(size.width / 2, rect.center.dy + size.height * .09)
      ..lineTo(rect.right - size.width * .04, rect.top + size.height * .08);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _MailLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
