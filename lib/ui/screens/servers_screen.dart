import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../state/app_state.dart';
import '../widgets/add_profile_sheet.dart';
import '../widgets/profile_tile.dart';
import 'package:provider/provider.dart';

class ServersScreen extends StatelessWidget {
  final bool fullPage;

  const ServersScreen({super.key, this.fullPage = false});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.watch<AppState>();
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              if (fullPage)
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              Expanded(
                child: Text(
                  l10n.serversTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (state.latencyTesting)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.speed_rounded),
                  tooltip: l10n.testLatency,
                  onPressed:
                      state.profiles.isEmpty ? null : state.testLatencies,
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.add_rounded),
                tooltip: l10n.addServer,
                onSelected: (value) => showAddSheet(context, value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'link',
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded),
                        const SizedBox(width: 12),
                        Text(l10n.addServer),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sub',
                    child: Row(
                      children: [
                        const Icon(Icons.rss_feed_rounded),
                        const SizedBox(width: 12),
                        Text(l10n.addSubscription),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: state.profiles.isEmpty
              ? Center(child: Text(l10n.noServers))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: state.profiles.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return _AutoTile(
                        enabled: state.engineProfiles.length > 1,
                      );
                    }
                    final profile = state.profiles[i - 1];
                    return ProfileTile(
                      profile: profile,
                      selected:
                          profile.id == state.selectedId && !state.autoSelect,
                      latency: state.latencies[profile.id],
                    );
                  },
                ),
        ),
      ],
    );

    if (fullPage) return Scaffold(body: SafeArea(child: body));
    return SafeArea(child: body);
  }
}

class _AutoTile extends StatelessWidget {
  final bool enabled;

  const _AutoTile({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final best = state.bestProfile;
    final subtitle = best != null
        ? '${l10n.fastest}: ${best.name} · ${state.latencies[best.id]} ${l10n.ms}'
        : l10n.autoFastestHint;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Card.filled(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: state.autoSelect ? scheme.primaryContainer : null,
        child: ListTile(
          onTap: enabled ? () => state.setAutoSelect(true) : null,
          leading: CircleAvatar(
            backgroundColor: state.autoSelect
                ? scheme.primary
                : scheme.surfaceContainerHighest,
            foregroundColor: state.autoSelect
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
            child: const Icon(Icons.bolt_rounded, size: 20),
          ),
          title: Text(
            l10n.autoFastest,
            style: TextStyle(
              fontWeight:
                  state.autoSelect ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          subtitle: Text(subtitle, overflow: TextOverflow.ellipsis),
          trailing: state.autoSelect
              ? Icon(Icons.check_circle_rounded, color: scheme.primary)
              : null,
        ),
      ),
    );
  }
}
