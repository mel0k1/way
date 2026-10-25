import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/vpn_bridge.dart';
import '../../state/app_state.dart';
import '../motion.dart';
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

    // Live speedometer: download bytes/s normalized to a 100 Mbps full scale.
    final gaugeValue =
        ((state.stats.downSpeed * 8 / 1e6) / 100).clamp(0.0, 1.0).toDouble();

    return GestureDetector(
      onTap: () => _tap(connected, busy),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: WayMotion.fast,
        curve: WayMotion.springy,
        child: SizedBox(
          width: 216,
          height: 216,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (connected) ...[
                _PulseRing(controller: _pulse, delay: 0, color: scheme.primary),
                _PulseRing(
                    controller: _pulse, delay: 0.5, color: scheme.primary),
              ],
              // Plain decorative ring while idle; replaced by the live
              // speedometer gauge once connected.
              if (!connected && !busy)
                Container(
                  width: 204,
                  height: 204,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.7),
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
              // Live speedometer arc around the shield while connected.
              if (connected)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: gaugeValue),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CustomPaint(
                    size: const Size(204, 204),
                    painter: _SpeedGaugePainter(
                      value: value,
                      track: scheme.surfaceContainerHighest,
                      color: scheme.primary,
                      colorHigh: scheme.tertiary,
                    ),
                  ),
                ),
              // Springy bounce whenever the connection state flips.
              TweenAnimationBuilder<double>(
                key: ValueKey(connected),
                tween: Tween(begin: 0.9, end: 1.0),
                duration: WayMotion.spring,
                curve: WayMotion.elastic,
                builder: (context, t, child) =>
                    Transform.scale(scale: t, child: child),
                child: _MorphBody(
                  connected: connected,
                  busy: busy,
                  scheme: scheme,
                  wave: _wave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The morphing button body: a circle when idle, a shield once connected.
class _MorphBody extends StatelessWidget {
  final bool connected;
  final bool busy;
  final ColorScheme scheme;
  final AnimationController wave;

  const _MorphBody({
    required this.connected,
    required this.busy,
    required this.scheme,
    required this.wave,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: WayMotion.slow,
      curve: WayMotion.morph,
      tween: Tween(begin: 0, end: connected ? 1.0 : 0.0),
      builder: (context, t, child) => CustomPaint(
        size: const Size(176, 176),
        painter: _ShapeMorphPainter(
          t: t,
          fill: connected ? scheme.primary : scheme.surfaceContainerHigh,
          border: connected ? scheme.surface : Colors.transparent,
          borderWidth: 8,
        ),
        child: child,
      ),
      child: SizedBox(
        width: 176,
        height: 176,
        child: Center(
          child: busy
              ? AnimatedBuilder(
                  animation: wave,
                  builder: (context, _) => CustomPaint(
                    size: const Size(150, 150),
                    painter: _WavyRingPainter(
                      phase: wave.value,
                      color: connected ? scheme.onPrimary : scheme.primary,
                    ),
                  ),
                )
              : AnimatedSwitcher(
                  duration: WayMotion.fast,
                  switchInCurve: WayMotion.springy,
                  switchOutCurve: WayMotion.emphasizedIn,
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    connected
                        ? Icons.shield_rounded
                        : Icons.power_settings_new_rounded,
                    key: ValueKey(connected),
                    size: 60,
                    color: connected ? scheme.onPrimary : scheme.primary,
                  ),
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
      final r =
          base + amplitude * math.sin(waves * theta + phase * 2 * math.pi);
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

/// Live download-speed gauge wrapping the connected button: a 270° arc with
/// a gradient sweep and a soft track.
class _SpeedGaugePainter extends CustomPainter {
  final double value;
  final Color track;
  final Color color;
  final Color colorHigh;

  _SpeedGaugePainter({
    required this.value,
    required this.track,
    required this.color,
    required this.colorHigh,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi * 0.75;
    const sweep = math.pi * 1.5;

    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = track.withValues(alpha: 0.55),
    );

    final v = value.clamp(0.0, 1.0);
    if (v <= 0.001) return;
    canvas.drawArc(
      rect,
      start,
      sweep * v,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: [color, colorHigh],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SpeedGaugePainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.track != track ||
      oldDelegate.color != color ||
      oldDelegate.colorHigh != colorHigh;
}

/// Interpolates between a circle contour (t = 0) and a shield contour
/// (t = 1). Both contours share the same anchor (top center) and winding
/// direction, so the morph stays clean without path-ops libraries.
class _ShapeMorphPainter extends CustomPainter {
  final double t;
  final Color fill;
  final Color border;
  final double borderWidth;

  _ShapeMorphPainter({
    required this.t,
    required this.fill,
    required this.border,
    required this.borderWidth,
  });

  static const _points = 140;

  @override
  void paint(Canvas canvas, Size size) {
    final body = _lerpContour(size);
    final path = Path()..addPolygon(body, true);
    if (borderWidth > 0 && border != Colors.transparent) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth
          ..color = border,
      );
    }
    canvas.drawPath(path, Paint()..color = fill);
  }

  List<Offset> _lerpContour(Size size) {
    final from = _circleContour(size);
    final to = _shieldContour(size);
    final tt = t.clamp(-0.2, 1.35);
    return List.generate(_points, (i) {
      final a = from[i];
      final b = to[i];
      return Offset(
        a.dx + (b.dx - a.dx) * tt,
        a.dy + (b.dy - a.dy) * tt,
      );
    });
  }

  static List<Offset> _circleContour(Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    return List.generate(_points, (i) {
      final a = -math.pi / 2 + i * 2 * math.pi / _points;
      return c + Offset(r * math.cos(a), r * math.sin(a));
    });
  }

  static List<Offset> _shieldContour(Size size) {
    final sw = size.width * 0.80;
    final sh = size.height * 0.94;
    final ox = (size.width - sw) / 2;
    final oy = (size.height - sh) / 2;
    final path = Path()
      ..moveTo(ox + sw / 2, oy)
      ..lineTo(ox + sw - sw * 0.10, oy)
      ..quadraticBezierTo(ox + sw, oy, ox + sw, oy + sw * 0.14)
      ..lineTo(ox + sw, oy + sh * 0.50)
      ..quadraticBezierTo(ox + sw, oy + sh * 0.72, ox + sw / 2, oy + sh)
      ..quadraticBezierTo(ox, oy + sh * 0.72, ox, oy + sh * 0.50)
      ..lineTo(ox, oy + sw * 0.14)
      ..quadraticBezierTo(ox, oy, ox + sw * 0.10, oy)
      ..close();
    final metric = path.computeMetrics().first;
    return List.generate(_points, (i) {
      final d = i * metric.length / _points;
      return metric.getTangentForOffset(d)?.position ?? Offset(ox + sw / 2, oy);
    });
  }

  @override
  bool shouldRepaint(_ShapeMorphPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.fill != fill ||
      oldDelegate.border != border;
}
