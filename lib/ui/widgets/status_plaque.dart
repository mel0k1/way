import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/vpn_bridge.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../motion.dart';
import 'package:provider/provider.dart';

/// Status plaque under the connect button: a pill that morphs with the VPN
/// phase and runs a travelling wave across itself while connecting — the
/// expressive version of a plain "Connecting…" label.
class StatusPlaque extends StatefulWidget {
  const StatusPlaque({super.key});

  @override
  State<StatusPlaque> createState() => _StatusPlaqueState();
}

class _StatusPlaqueState extends State<StatusPlaque>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
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
    final error = state.vpn.error != null;
    final animateWaves =
        busy && !MediaQuery.disableAnimationsOf(context);

    if (animateWaves && !_wave.isAnimating) {
      _wave.repeat();
    } else if (!animateWaves && _wave.isAnimating) {
      _wave.stop();
    }

    final bg = error
        ? scheme.errorContainer
        : connected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh;
    final fg = error
        ? scheme.onErrorContainer
        : connected
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant;

    var text = switch (phase) {
      VpnPhase.connected => l10n.connected,
      VpnPhase.connecting => l10n.connecting,
      VpnPhase.disconnecting => l10n.disconnecting,
      VpnPhase.stopped => l10n.stopped,
    };
    if (error) {
      text = l10n.errorText(state.vpn.error);
    } else if (state.isReconnecting && phase == VpnPhase.stopped) {
      text = l10n.reconnectingAttempt(state.reconnectAttempt);
    }

    return AnimatedContainer(
      duration: WayMotion.medium,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
          width: error || connected ? 0 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Travelling wave across the plaque while busy.
            if (busy)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _wave,
                  builder: (context, _) => CustomPaint(
                    painter: _WavyFlowPainter(
                      phase: _wave.value * 2 * math.pi,
                      color: error ? scheme.error : scheme.primary,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: WayMotion.fast,
                    switchInCurve: WayMotion.springy,
                    switchOutCurve: WayMotion.emphasizedIn,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: _PlaqueIcon(
                      key: ValueKey(phase),
                      phase: phase,
                      error: error,
                      fg: fg,
                      scheme: scheme,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaqueIcon extends StatelessWidget {
  final VpnPhase phase;
  final bool error;
  final Color fg;
  final ColorScheme scheme;
  const _PlaqueIcon({
    super.key,
    required this.phase,
    required this.error,
    required this.fg,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    if (error) {
      return Icon(Icons.error_outline_rounded, size: 18, color: fg);
    }
    return switch (phase) {
      VpnPhase.connected =>
        Icon(Icons.shield_rounded, size: 18, color: fg),
      VpnPhase.stopped => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fg.withValues(alpha: 0.55),
          ),
        ),
      _ => SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            strokeCap: StrokeCap.round,
            color: scheme.primary,
          ),
        ),
    };
  }
}

/// Two layered sine flows running across the plaque — read as motion, not
/// noise, thanks to low amplitude and translucent strokes.
class _WavyFlowPainter extends CustomPainter {
  final double phase;
  final Color color;

  _WavyFlowPainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final layers = [
      (0.34, 3.2, 0.0, 2.2, 0.30),
      (0.66, 2.4, 1.9, 1.7, 0.18),
    ];
    for (final (rel, amp, shift, freq, alpha) in layers) {
      final path = Path();
      const steps = 96;
      for (var i = 0; i <= steps; i++) {
        final x = size.width * i / steps;
        final y = size.height * rel +
            amp * math.sin(freq * 2 * math.pi * i / steps -
                phase +
                shift);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_WavyFlowPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
