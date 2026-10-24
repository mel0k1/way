import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return ColoredBox(
      color: scheme.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.15, -1.05),
                  radius: 1.4,
                  colors: [
                    scheme.primary.withValues(alpha: dark ? 0.17 : 0.11),
                    scheme.primary.withValues(alpha: 0),
                  ],
                  stops: const [0, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-1.25, 1.15),
                  radius: 1.3,
                  colors: [
                    scheme.tertiary.withValues(alpha: dark ? 0.14 : 0.09),
                    scheme.tertiary.withValues(alpha: 0),
                  ],
                  stops: const [0, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.85, -0.95),
                  radius: 0.95,
                  colors: [
                    scheme.secondary.withValues(alpha: dark ? 0.07 : 0.05),
                    scheme.secondary.withValues(alpha: 0),
                  ],
                  stops: const [0, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
