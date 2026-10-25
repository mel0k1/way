import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../state/app_state.dart';
import '../motion.dart';
import '../widgets/add_profile_sheet.dart';
import '../widgets/profile_tile.dart';
import '../widgets/qr_export_dialog.dart';
import 'package:provider/provider.dart';

class ServersScreen extends StatelessWidget {
  final bool fullPage;

  const ServersScreen({super.key, this.fullPage = false});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final visible = state.visibleProfiles;
    final searching = state.serverQuery.isNotEmpty;

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
                onSelected: (value) async {
                  if (value == 'file') {
                    final app = context.read<AppState>();
                    final before = app.profiles.length;
                    await app.importFromFile();
                    final added = app.profiles.length - before;
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          added > 0 ? l10n.imported : l10n.importFromFileEmpty),
                      behavior: SnackBarBehavior.floating,
                      width: 320,
                    ));
                  } else {
                    showAddSheet(context, value);
                  }
                },
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
                  PopupMenuItem(
                    value: 'file',
                    child: Row(
                      children: [
                        const Icon(Icons.upload_file_rounded),
                        const SizedBox(width: 12),
                        Text(l10n.importFromFile),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (state.profiles.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: _SearchField(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  state.serverSort == 'latency'
                      ? Icons.speed_rounded
                      : state.serverSort == 'name'
                          ? Icons.sort_by_alpha_rounded
                          : Icons.low_priority_rounded,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  searching
                      ? l10n.foundCount(visible.length)
                      : '${visible.length} ${l10n.entries}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: l10n.sortBy,
                  onSelected: state.setServerSort,
                  position: PopupMenuPosition.under,
                  icon: const Icon(Icons.sort_rounded, size: 20),
                  itemBuilder: (context) => [
                    for (final entry in {
                      'default': l10n.sortDefault,
                      'latency': l10n.sortLatency,
                      'name': l10n.sortName,
                    }.entries)
                      CheckedPopupMenuItem(
                        value: entry.key,
                        checked: state.serverSort == entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                ),
                IconButton(
                  tooltip: l10n.transferQr,
                  icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                  onPressed: () => showQrTransfer(context, state),
                ),
              ],
            ),
          ),
        ],
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
              : visible.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          l10n.noAppsFound,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: visible.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _Entrance(
                            index: 0,
                            child: _AutoTile(
                              enabled: state.engineProfiles.length > 1,
                            ),
                          );
                        }
                        final profile = visible[i - 1];
                        final previous = i >= 2 ? visible[i - 2] : null;
                        final showFavHeader = profile.favorite &&
                            (previous == null || !previous.favorite);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showFavHeader)
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 12, top: 10, bottom: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      l10n.favorites,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.4,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            _Entrance(
                              index: i,
                              child: ProfileTile(
                                profile: profile,
                                // Compare with the resolved selection (which
                                // falls back to the first profile) so the
                                // highlight always matches what connect()
                                // will actually use.
                                selected: profile.id == state.selected?.id &&
                                    !state.autoSelect,
                                latency: state.latencies[profile.id],
                              ),
                            ),
                          ],
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

class _SearchField extends StatefulWidget {
  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller;
  bool _empty = true;

  @override
  void initState() {
    super.initState();
    final initial = context.read<AppState>().serverQuery;
    _empty = initial.isEmpty;
    _controller = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onChanged: (v) {
        state.setServerQuery(v);
        if ((v.isEmpty) != _empty) setState(() => _empty = v.isEmpty);
      },
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _empty
            ? null
            : IconButton(
                iconSize: 18,
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _controller.clear();
                  state.setServerQuery('');
                  setState(() => _empty = true);
                },
              ),
        hintText: l10n.searchServers,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
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
    );
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
      duration: Duration(
          milliseconds:
              WayMotion.slow.inMilliseconds + (delay * 600).round()),
      curve: Interval(delay, 1, curve: WayMotion.springy),
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
        margin: const EdgeInsets.only(top: 4, bottom: 4),
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
