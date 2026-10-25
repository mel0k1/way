import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Material 3 Expressive wavy section divider: a thin sine line that drifts
/// slowly, flanked by an optional label chip (e.g. "Favorites").
///
/// Respects the platform "remove animations" accessibility setting.
class WavyDivider extends StatefulWidget {
  final String? label;
  final Color? color;
  final double topGap;
  final double bottomGap;

  const WavyDivider({super.key, this.label, this.color, this.topGap = 14, this.bottomGap = 10});

  @override
  State<WavyDivider> createState() => _WavyDividerState();
}

class _WavyDividerState extends State<WavyDivider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );

  @override
  void initState() {
    super.initState();
    _c.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disabled && _c.isAnimating) _c.stop();
    if (!disabled && !_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.color ?? scheme.outlineVariant;
    final label = widget.label;
    return Padding(
      padding: EdgeInsets.only(top: widget.topGap, bottom: widget.bottomGap),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final wave = CustomPaint(
              size: const Size.fromHeight(10),
              painter: _WavyDividerPainter(
                phase: _c.value,
                color: color,
              ),
            );
            if (label == null) return wave;
            return Row(
              children: [
                Expanded(child: wave),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                  ),
                ),
                Expanded(child: wave),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WavyDividerPainter extends CustomPainter {
  final double phase;
  final Color color;

  _WavyDividerPainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final midY = size.height / 2;
    const amplitude = 2.4;
    final waves = (w / 42).clamp(3.0, 9.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color;
    final path = Path()..moveTo(0, midY);
    for (var x = 0.0; x <= w; x += 3) {
      final t = x / w;
      final y = midY +
          amplitude * math.sin(2 * math.pi * (waves * t + phase));
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavyDividerPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
