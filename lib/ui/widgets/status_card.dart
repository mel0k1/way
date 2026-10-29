import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/stats.dart';
import '../../core/vpn_bridge.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../screens/connections_screen.dart';
import 'format.dart';
import 'package:provider/provider.dart';

export 'format.dart' show formatBytes, formatSpeed;

String? _flag(String? code) {
  if (code == null || code.length != 2) return null;
  final base = 0x1F1E6;
  return String.fromCharCodes(
      code.toUpperCase().runes.map((c) => base + c - 65));
}

String _totalsLine(L10n l10n, WayStats stats) {
  return '${l10n.total}: ↓ ${formatBytes(stats.totalDown)} · ↑ '
      '${formatBytes(stats.totalUp)} · ${stats.connections} ${l10n.connectionsLabel.toLowerCase()}';
}

class StatusCard extends StatelessWidget {
  const StatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final profile = state.selected;
    final connected = state.vpn.phase == VpnPhase.connected;

    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: connected
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                  ),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: child,
                    ),
                    child: Icon(
                      profile == null
                          ? Icons.help_outline_rounded
                          : Icons.dns_rounded,
                      key: ValueKey(connected),
                      size: 20,
                      color: connected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    profile?.name ?? l10n.noProfileSelected,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (profile != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: scheme.secondaryContainer,
                    ),
                    child: Text(
                      profile.protocolLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (profile != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Text(
                  '${profile.server}:${profile.port}',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (connected &&
                (state.connCountry?.isNotEmpty == true ||
                    state.connIp?.isNotEmpty == true)) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Row(
                  children: [
                    Icon(Icons.public_rounded,
                        size: 14, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          _flag(state.connCountry) ?? state.connCountry,
                          state.connIp
                        ]
                            .where((e) => e?.isNotEmpty == true)
                            .join(' · '),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SpeedTile(
                    icon: Icons.south_rounded,
                    label: l10n.downSpeed,
                    value: connected ? formatSpeed(state.stats.downSpeed) : '—',
                    highlight: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SpeedTile(
                    icon: Icons.north_rounded,
                    label: l10n.upSpeed,
                    value: connected ? formatSpeed(state.stats.upSpeed) : '—',
                    highlight: scheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.isReconnecting) ...[
              _WatchdogChip(attempt: state.reconnectAttempt),
              const SizedBox(height: 12),
            ],
            if (connected) ...[
              _SpeedTestRow(state: state),
              const SizedBox(height: 12),
            ],
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: connected
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ConnectionsScreen()),
                      )
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  connected
                      ? _totalsLine(l10n, state.stats)
                      : l10n.totalIdle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (connected) ...[
              const SizedBox(height: 12),
              const _WaveLine(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Springy pill shown while the watchdog is scheduling a reconnect.
class _WatchdogChip extends StatelessWidget {
  final int attempt;

  const _WatchdogChip({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: scheme.tertiaryContainer,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.autorenew_rounded,
                size: 14, color: scheme.onTertiaryContainer),
            const SizedBox(width: 6),
            Text(
              L10nScope.of(context).reconnectingAttempt(attempt),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slow, calm wave underline — a quiet "alive" signal while connected.
class _WaveLine extends StatefulWidget {
  const _WaveLine();

  @override
  State<_WaveLine> createState() => _WaveLineState();
}

class _WaveLineState extends State<_WaveLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the platform "remove animations" accessibility setting.
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disabled && _c.isAnimating) {
      _c.stop();
    } else if (!disabled && !_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void initState() {
    super.initState();
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: const Size.fromHeight(8),
        painter: _WaveLinePainter(phase: _c.value, color: scheme.primary),
      ),
    );
  }
}

class _WaveLinePainter extends CustomPainter {
  final double phase;
  final Color color;

  _WaveLinePainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final midY = size.height / 2;
    const amplitude = 2.2;
    const waves = 5.0;
    final path = Path()..moveTo(0, midY);
    for (var x = 0.0; x <= w; x += 4) {
      final t = x / w;
      final y = midY +
          amplitude * math.sin(2 * math.pi * (waves * t + phase));
      path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_WaveLinePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}

/// Speed test chip: measures download through the current route and shows
/// the result inline.
class _SpeedTestRow extends StatelessWidget {
  final AppState state;

  const _SpeedTestRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final testing = state.speedTesting;
    final result = state.speedtestMbps;
    String label;
    if (testing) {
      label = l10n.speedtesting;
    } else if (result != null) {
      label = l10n.speedtestResult(result >= 10
          ? result.toStringAsFixed(1)
          : result.toStringAsFixed(2));
    } else {
      label = l10n.speedtest;
    }
    return Row(
      children: [
        SizedBox(
          height: 34,
          child: FilledButton.tonalIcon(
            onPressed: testing ? null : state.runSpeedTest,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 34),
              textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            icon: testing
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.speed_rounded, size: 16),
            label: Text(label),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            result == null && !testing ? l10n.speedtestHint : '',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _SpeedTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color highlight;

  const _SpeedTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceContainerHigh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: highlight),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInToLinear,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.centerLeft,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            ),
            transitionBuilder: (child, anim) {
              final incoming = child.key == ValueKey<String>(value);
              return ClipRect(
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: incoming ? const Offset(0, 0.35) : const Offset(0, -0.35),
                    end: Offset.zero,
                  ).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
              );
            },
            child: Text(
              value,
              key: ValueKey<String>(value),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
