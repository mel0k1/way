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
    final scheme = Theme.of(context).colorScheme;
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
                IconButton.filledTonal(
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
              ? Center(
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
                        child: Icon(Icons.dns_rounded,
                            size: 40, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          l10n.noServers,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: state.profiles.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return _Entrance(
                        index: 0,
                        child: _AutoTile(
                          enabled: state.engineProfiles.length > 1,
                        ),
                      );
                    }
                    final profile = state.profiles[i - 1];
                    return _Entrance(
                      index: i,
                      child: ProfileTile(
                        profile: profile,
                        // Compare with the resolved selection (which falls
                        // back to the first profile) so the highlight always
                        // matches what connect() will actually use.
                        selected: profile.id == state.selected?.id &&
                            !state.autoSelect,
                        latency: state.latencies[profile.id],
                      ),
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

class _Entrance extends StatelessWidget {
  final int index;
  final Widget child;

  const _Entrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    // Staggered expressive entrance: slide + fade with a slight spring
    // overshoot, capped so long lists don't wait forever.
    final delay = (index.clamp(0, 10) * 45) / 600.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: (420 + delay * 600).round()),
      curve: Interval(delay, 1, curve: Curves.easeOutBack),
      builder: (context, t, child) {
        final clamped = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: clamped,
          child: Transform.translate(
            offset: Offset(0, 26 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
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
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: state.autoSelect
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.bolt_rounded,
              size: 22,
              color: state.autoSelect
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant,
            ),
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
