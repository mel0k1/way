import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/vpn_bridge.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import 'package:provider/provider.dart';

class ConnectButton extends StatefulWidget {
  const ConnectButton({super.key});

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _pressed = false;

  @override
  void dispose() {
    _pulse.dispose();
    _wave.dispose();
    _spin.dispose();
    super.dispose();
  }

  void _tap(bool connected, bool busy) {
    final app = context.read<AppState>();
    if (connected) {
      app.disconnect();
    } else if (!busy) {
      app.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final connected = state.vpn.phase == VpnPhase.connected;
    final busy = state.vpn.phase == VpnPhase.connecting ||
        state.vpn.phase == VpnPhase.disconnecting;

    if (connected && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!connected && _pulse.isAnimating) {
      _pulse.stop();
    }
    if (busy && !_wave.isAnimating) {
      _wave.repeat();
    } else if (!busy && _wave.isAnimating) {
      _wave.stop();
    }
    if (busy && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!busy && _spin.isAnimating) {
      _spin.stop();
    }

    return GestureDetector(
      onTap: () => _tap(connected, busy),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutBack,
        child: SizedBox(
          width: 216,
          height: 216,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (connected) ...[
                _PulseRing(controller: _pulse, delay: 0, color: scheme.primary),
                _PulseRing(
                    controller: _pulse,
                    delay: 0.5,
                    color: scheme.primary),
              ],
              Container(
                width: 204,
                height: 204,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: connected
                        ? scheme.primary.withValues(alpha: 0.45)
                        : scheme.outlineVariant.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                ),
              ),
              // Expressive loading halo: a rotating gradient arc while busy.
              if (busy)
                AnimatedBuilder(
                  animation: _spin,
                  builder: (context, _) => CustomPaint(
                    size: const Size(204, 204),
                    painter: _SpinHaloPainter(
                      rotation: _spin.value,
                      color: scheme.primary,
                    ),
                  ),
                ),
              // Springy bounce whenever the connection state flips.
              TweenAnimationBuilder<double>(
                key: ValueKey(connected),
                tween: Tween(begin: 0.9, end: 1.0),
                duration: const Duration(milliseconds: 520),
                curve: Curves.elasticOut,
                builder: (context, t, child) =>
                    Transform.scale(scale: t, child: child),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Easing.standard,
                  width: connected ? 176 : 168,
                  height: connected ? 176 : 168,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected
                        ? scheme.primary
                        : scheme.surfaceContainerHigh,
                    border: Border.all(
                      color: connected ? scheme.surface : Colors.transparent,
                      width: 8,
                    ),
                    boxShadow: [
                      if (connected)
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.32),
                          blurRadius: 44,
                          spreadRadius: 4,
                        ),
                    ],
                  ),
                  child: busy
                      ? AnimatedBuilder(
                          animation: _wave,
                          builder: (context, _) => CustomPaint(
                            painter: _WavyRingPainter(
                              phase: _wave.value,
                              color: connected
                                  ? scheme.onPrimary
                                  : scheme.primary,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.power_settings_new_rounded,
                          size: 62,
                          color: connected
                              ? scheme.onPrimary
                              : scheme.primary,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Material 3 Expressive-style wavy circular progress: a ring whose radius
/// ripples with a travelling sine wave while the connection is busy.
class _WavyRingPainter extends CustomPainter {
  final double phase;
  final Color color;

  _WavyRingPainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.shortestSide / 2 - 4;
    const waves = 6.0;
    const amplitude = 4.0;

    final path = Path();
    const steps = 240;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final theta = t * 2 * math.pi;
      final r = base +
          amplitude * math.sin(waves * theta + phase * 2 * math.pi);
      final p = center + Offset(r * math.cos(theta), r * math.sin(theta));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_WavyRingPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}

/// Rotating gradient halo around the outer ring while connecting — the
/// classic expressive "working" indicator.
class _SpinHaloPainter extends CustomPainter {
  final double rotation;
  final Color color;

  _SpinHaloPainter({required this.rotation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2 + rotation * 2 * math.pi,
      math.pi * 0.85,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 0.85,
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.85),
          ],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SpinHaloPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.color != color;
}

class _PulseRing extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Color color;

  const _PulseRing({
    required this.controller,
    required this.delay,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (controller.value - delay).clamp(0.0, 1.0) / (1 - delay);
        final eased = Curves.easeOut.transform(t);
        return Container(
          width: 176 + 96 * eased,
          height: 176 + 96 * eased,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.30 * (1 - eased)),
              width: 2.5,
            ),
          ),
        );
      },
    );
  }
}

class StatusLabel extends StatelessWidget {
  const StatusLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = switch (state.vpn.phase) {
      VpnPhase.connected => l10n.connected,
      VpnPhase.connecting => l10n.connecting,
      VpnPhase.disconnecting => l10n.disconnecting,
      VpnPhase.stopped => l10n.stopped,
    };
    if (state.vpn.error != null) {
      return Text(
        l10n.errorText(state.vpn.error),
        style: TextStyle(
          color: scheme.error,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      );
    }
    final connected = state.vpn.phase == VpnPhase.connected;
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: connected ? scheme.primary : scheme.onSurfaceVariant,
          ),
    );
  }
}
