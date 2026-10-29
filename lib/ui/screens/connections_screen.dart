import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/connections.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../motion.dart';
import '../widgets/format.dart' show formatBytes, formatSpeed;

/// Live connections viewer (Karing's net_connections_screen): what is flowing
/// through the tunnel right now, with per-connection speeds and kill actions.
class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  final ConnectionsPoller _poller = ConnectionsPoller();
  final TextEditingController _search = TextEditingController();
  Timer? _timer;
  ConnectionsSnapshot _snapshot = ConnectionsSnapshot.empty;
  bool _loading = true;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _poller.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final snap = await _poller.fetch();
    if (!mounted) return;
    setState(() {
      _snapshot = snap;
      _loading = false;
    });
  }

  Future<void> _closeOne(LiveConnection c) async {
    setState(() => _closing = true);
    await _poller.close(c.id);
    if (!mounted) return;
    setState(() => _closing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(L10nScope.of(context).connectionClosed),
      behavior: SnackBarBehavior.floating,
      width: 320,
    ));
  }

  Future<void> _closeAll() async {
    final l10n = L10nScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.closeAll),
        content: Text(l10n.closeAllConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.closeAll),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _poller.closeAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.allClosed),
      behavior: SnackBarBehavior.floating,
      width: 320,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final connected = state.vpn.phase == VpnPhase.connected;

    final q = _search.text.trim().toLowerCase();
    final conns = q.isEmpty
        ? _snapshot.connections
        : _snapshot.connections.where((c) {
            return c.bestHost.toLowerCase().contains(q) ||
                c.process.toLowerCase().contains(q) ||
                c.rule.toLowerCase().contains(q) ||
                c.chains.any((e) => e.toLowerCase().contains(q));
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.connectionsTitle),
        actions: [
          if (conns.isNotEmpty)
            IconButton(
              tooltip: l10n.closeAll,
              icon: _closing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.link_off_rounded),
              onPressed: _closing ? null : _closeAll,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _SummaryStrip(
                snapshot: _snapshot,
                count: conns.length,
                connected: connected,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon:
                      const Icon(Icons.search_rounded, size: 20),
                  hintText: l10n.searchServers,
                  filled: true,
                  fillColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: scheme.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : !_snapshot.ok
                      ? _EmptyView(
                          icon: Icons.vpn_key_off_rounded,
                          text: l10n.connectionsNeedVpn,
                        )
                      : conns.isEmpty
                          ? _EmptyView(
                              icon: Icons.inbox_rounded,
                              text: q.isNotEmpty
                                  ? l10n.noAppsFound
                                  : l10n.connectionsEmpty,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: conns.length,
                              itemBuilder: (context, i) {
                                final c = conns[i];
                                return _ConnectionTile(
                                  connection: c,
                                  onClose: () => _closeOne(c),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final ConnectionsSnapshot snapshot;
  final int count;
  final bool connected;

  const _SummaryStrip({
    required this.snapshot,
    required this.count,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ok = snapshot.ok && connected;
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ok
            ? Row(
                children: [
                  Icon(Icons.monitor_heart_outlined,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${count} ${l10n.connectionsPlural(count)}'
                      ' · ${l10n.connectionsLive}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '↓ ${formatSpeed(snapshot.downSpeed)}'
                    ' · ↑ ${formatSpeed(snapshot.upSpeed)}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(Icons.monitor_heart_outlined,
                      size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      connected
                          ? l10n.connectionsLive
                          : l10n.connectionsNeedVpn,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  final LiveConnection connection;
  final VoidCallback onClose;

  const _ConnectionTile({required this.connection, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final c = connection;
    final chain = c.chains.isEmpty ? '' : c.chains.reversed.join(' → ');
    final sub = [
      if (chain.isNotEmpty) chain,
      if (c.process.isNotEmpty) c.process,
      if (c.rule.isNotEmpty)
        c.rulePayload.isNotEmpty
            ? '${c.rule}: ${c.rulePayload}'
            : c.rule,
      c.network.toUpperCase(),
    ].join(' · ');
    final isUdp = c.network == 'udp';
    return AnimatedSize(
      duration: WayMotion.medium,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Card.filled(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: ListTile(
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: scheme.surfaceContainerHighest,
            ),
            alignment: Alignment.center,
            child: Icon(
              isUdp
                  ? Icons.swap_vert_rounded
                  : c.host.isEmpty
                      ? Icons.lan_rounded
                      : Icons.language_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ),
          title: Text(
            c.bestHost,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            sub.isEmpty ? '—' : sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '↓ ${formatSpeed(c.downSpeed)}  ↑ ${formatSpeed(c.upSpeed)}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    '${formatBytes(c.download)} / ${formatBytes(c.upload)}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              IconButton(
                tooltip: l10n.closeConnection,
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: Icon(
                  Icons.close_rounded,
                  color: scheme.error.withValues(alpha: 0.75),
                ),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyView({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerHighest,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 40, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
