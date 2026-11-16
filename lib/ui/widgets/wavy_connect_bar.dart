import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/vpn_bridge.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../motion.dart';

class WavyConnectBar extends StatefulWidget {
  const WavyConnectBar({super.key});

  @override
  State<WavyConnectBar> createState() => _WavyConnectBarState();
}

class _WavyConnectBarState extends State<WavyConnectBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  bool _pressed = false;

  @override
  void dispose() {
    _phase.dispose();
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
    final l10n = L10nScope.of(context);
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final phase = state.vpn.phase;
    final connected = phase == VpnPhase.connected;
    final busy = phase == VpnPhase.connecting ||
        phase == VpnPhase.disconnecting;

    final animate =
        (connected || busy) && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_phase.isAnimating) {
      _phase.repeat();
    } else if (!animate && _phase.isAnimating) {
      _phase.stop();
    }

    final bg = connected ? scheme.primary : scheme.secondaryContainer;
    final fg = connected ? scheme.onPrimary : scheme.onSecondaryContainer;

    var label = connected ? '' : l10n.connect;
    if (phase == VpnPhase.connecting) label = l10n.connecting;
    if (phase == VpnPhase.disconnecting) label = l10n.disconnecting;

    final fill = connected || phase == VpnPhase.connecting ? 1.0 : 0.0;

    return GestureDetector(
      onTap: () => _tap(connected, busy),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: WayMotion.fast,
        curve: WayMotion.springy,
        child: AnimatedContainer(
          duration: WayMotion.medium,
          curve: Curves.easeOutCubic,
          height: 64,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: connected ? 0.20 : 0.10),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fill),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, fillValue, _) => AnimatedBuilder(
                      animation: _phase,
                      builder: (context, _) => CustomPaint(
                        painter: _WavyBarPainter(
                          phasePx: _phase.value * 28,
                          fill: fillValue,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                ),
                if (label.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: 0.2,
                        color: fg,
                      ),
                    ),
                  ),
                if (connected)
                  Icon(
                    Icons.shield_rounded,
                    size: 24,
                    color: fg.withValues(alpha: 0.0),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WavyBarPainter extends CustomPainter {
  final double phasePx;
  final double fill;
  final Color color;

  _WavyBarPainter({
    required this.phasePx,
    required this.fill,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const wavelength = 28.0;
    const amplitude = 5.0;
    const stroke = 6.0;
    const inset = 14.0;
    final midY = size.height / 2;
    final span = size.width - inset * 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.28);
    canvas.drawLine(
      Offset(inset, midY),
      Offset(size.width - inset, midY),
      track,
    );

    final filled = span * fill.clamp(0.0, 1.0);
    if (filled <= stroke) return;

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(inset, 0, math.max(0, filled - 4), size.height),
    );
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final path = Path();
    var first = true;
    for (var x = inset; x <= size.width - inset; x += 2) {
      final y =
          midY + amplitude * math.sin(2 * math.pi * (x - phasePx) / wavelength);
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, wave);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WavyBarPainter oldDelegate) =>
      oldDelegate.phasePx != phasePx ||
      oldDelegate.fill != fill ||
      oldDelegate.color != color;
}
