import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: CustomPaint(
        painter: _ShapesPainter(scheme),
        size: Size.infinite,
      ),
    );
  }
}

class _ShapesPainter extends CustomPainter {
  final ColorScheme scheme;

  _ShapesPainter(this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    final dark = scheme.brightness == Brightness.dark;
    final tint = dark
        ? Color.lerp(scheme.primary, Colors.white, 0.35)!
        : Color.lerp(scheme.primary, Colors.black, 0.30)!;
    final faint = dark ? 0.10 : 0.07;
    final softer = dark ? 0.07 : 0.05;

    canvas.drawCircle(
      Offset(size.width * 1.04, size.height * 0.04),
      size.width * 0.46,
      Paint()..color = tint.withValues(alpha: faint),
    );

    canvas.save();
    canvas.translate(size.width * 0.05, size.height * 0.90);
    canvas.rotate(-0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * 0.50,
          height: size.width * 0.50,
        ),
        Radius.circular(size.width * 0.16),
      ),
      Paint()..color = tint.withValues(alpha: softer),
    );
    canvas.restore();

    canvas.drawCircle(
      Offset(-size.width * 0.03, size.height * 0.36),
      size.width * 0.30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.022
        ..color = tint.withValues(alpha: softer),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.88, size.height * 0.82),
          width: size.width * 0.16,
          height: size.width * 0.16,
        ),
        Radius.circular(size.width * 0.05),
      ),
      Paint()..color = tint.withValues(alpha: faint * 0.9),
    );

    canvas.drawCircle(
      Offset(size.width * 0.30, size.height * 0.13),
      size.width * 0.045,
      Paint()..color = tint.withValues(alpha: softer),
    );
  }

  @override
  bool shouldRepaint(_ShapesPainter oldDelegate) =>
      oldDelegate.scheme != scheme;
}
