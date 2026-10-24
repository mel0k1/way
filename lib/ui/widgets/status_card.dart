import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/stats.dart';
import '../../core/vpn_bridge.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import 'package:provider/provider.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

String formatSpeed(int bytes) => '${formatBytes(bytes)}/s';

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
                  child: Icon(
                    profile == null
                        ? Icons.help_outline_rounded
                        : Icons.dns_rounded,
                    size: 20,
                    color: connected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
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
            Text(
              connected ? _totalsLine(l10n, state.stats) : l10n.totalIdle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
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
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
