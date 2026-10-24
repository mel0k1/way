import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Material 3 Expressive ambient background.
///
/// Four soft radial colour washes on the surface colour. The two strongest
/// washes slowly drift on independent sine oscillators so the backdrop feels
/// alive; the movement is isolated behind a [RepaintBoundary] and respects
/// the system "remove animations" accessibility setting.
class AppBackground extends StatefulWidget {
  const AppBackground({super.key});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  );

  @override
  void initState() {
    super.initState();
    _drift.repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final animate =
        !MediaQuery.of(context).disableAnimations;

    return RepaintBoundary(
      child: ColoredBox(
        color: scheme.surface,
        child: AnimatedBuilder(
          animation: _drift,
          builder: (context, _) {
            final t = animate ? _drift.value : 0.0;
            // Two independent oscillators (phase-shifted sines).
            final o1 = math.sin(t * 2 * math.pi);
            final o2 = math.sin((t + 0.38) * 2 * math.pi);

            return Stack(
              children: [
                _wash(
                  center: Alignment(1.15 + 0.14 * o1, -1.05 + 0.12 * o2),
                  radius: 1.45,
                  color: scheme.primary,
                  alpha: dark ? 0.20 : 0.12,
                ),
                _wash(
                  center: Alignment(-1.25 + 0.16 * o2, 1.15 + 0.13 * o1),
                  radius: 1.35,
                  color: scheme.tertiary,
                  alpha: dark ? 0.17 : 0.10,
                ),
                _wash(
                  center: const Alignment(-0.85, -0.95),
                  radius: 0.95,
                  color: scheme.secondary,
                  alpha: dark ? 0.07 : 0.05,
                ),
                _wash(
                  center: Alignment(0.9 + 0.1 * o2, 1.2 - 0.08 * o1),
                  radius: 0.9,
                  color: scheme.primary,
                  alpha: dark ? 0.10 : 0.06,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _wash({
    required Alignment center,
    required double radius,
    required Color color,
    required double alpha,
  }) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: radius,
            colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
            stops: const [0, 1],
          ),
        ),
      ),
    );
  }
}
