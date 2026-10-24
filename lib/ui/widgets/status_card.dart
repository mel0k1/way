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
                Icon(
                  profile == null ? Icons.help_outline_rounded : Icons.dns_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    profile?.name ?? l10n.noProfileSelected,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (profile != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      profile.protocolLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            if (profile != null) ...[
              const SizedBox(height: 4),
              Text(
                '${profile.server}:${profile.port}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (connected &&
                (state.connCountry?.isNotEmpty == true ||
                    state.connIp?.isNotEmpty == true)) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.public_rounded, size: 14, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [_flag(state.connCountry) ?? state.connCountry, state.connIp]
                          .where((e) => e?.isNotEmpty == true)
                          .join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Speed(
                  icon: Icons.south_rounded,
                  label: l10n.downSpeed,
                  value: connected ? formatSpeed(state.stats.downSpeed) : '—',
                  highlight: scheme.primary,
                ),
                _Speed(
                  icon: Icons.north_rounded,
                  label: l10n.upSpeed,
                  value: connected ? formatSpeed(state.stats.upSpeed) : '—',
                  highlight: scheme.tertiary,
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
          ],
        ),
      ),
    );
  }
}

class _Speed extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color highlight;

  const _Speed({
    required this.icon,
    required this.label,
    required this.value,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: highlight),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
