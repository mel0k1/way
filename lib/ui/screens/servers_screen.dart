import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../state/app_state.dart';
import '../motion.dart';
import '../widgets/add_profile_sheet.dart';
import '../widgets/profile_tile.dart';
import '../widgets/qr_export_dialog.dart';

class ServersScreen extends StatefulWidget {
  final bool fullPage;

  const ServersScreen({super.key, this.fullPage = false});

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  /// Collapsed group keys: 'fav', 'manual' or the subscription id.
  final Set<String> _collapsed = {};

  String _key(ServerGroup g) {
    if (g.favorite) return 'fav';
    if (g.subId.isEmpty) return 'manual';
    return g.subId;
  }

  bool _isCollapsed(ServerGroup g, bool searching) {
    // While searching every group expands so no hit can hide behind a fold.
    if (searching) return false;
    return _collapsed.contains(_key(g));
  }

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    AppState state,
    ServerGroup group,
    String title,
  ) async {
    final l10n = L10nScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteGroupConfirm(title, group.profiles.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (group.subId.isEmpty) {
      // Manually added servers — drop the whole bucket by ids.
      state.removeProfilesByIds([for (final p in group.profiles) p.id]);
    } else {
      // Subscription profile: its servers would be refetched on the next
      // update, so remove the subscription itself along with the servers.
      state.removeSubscription(group.subId);
    }
    if (!mounted) return;
    setState(() => _collapsed.remove(_key(group)));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.groupDeleted(title)),
      behavior: SnackBarBehavior.floating,
      width: 320,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final groups = state.serverGroups;
    final searching = state.serverQuery.isNotEmpty;
    final visibleCount =
        groups.fold<int>(0, (n, g) => n + g.profiles.length);

    // Slot plan: index 0 is the auto tile, then per group a header slot and
    // a tile-block slot (the block itself collapses via AnimatedSize).
    final slots = <_Slot>[];
    slots.add(const _Slot.auto());
    for (var gi = 0; gi < groups.length; gi++) {
      slots.add(_Slot.header(gi));
      slots.add(_Slot.block(gi));
    }

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              if (widget.fullPage)
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
                      ? l10n.foundCount(visibleCount)
                      : '$visibleCount ${l10n.serversPlural(visibleCount)}',
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
              : visibleCount == 0
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
                      itemCount: slots.length,
                      itemBuilder: (context, i) {
                        final slot = slots[i];
                        switch (slot.kind) {
                          case 0:
                            return _Entrance(
                              index: 0,
                              child: _AutoTile(
                                enabled: state.engineProfiles.length > 1,
                              ),
                            );
                          case 1:
                            return _buildGroupHeader(
                              context,
                              state,
                              groups[slot.group],
                              searching,
                            );
                          default:
                            return _buildGroupBlock(
                              context,
                              state,
                              groups[slot.group],
                              searching,
                            );
                        }
                      },
                    ),
        ),
      ],
    );

    if (widget.fullPage) return Scaffold(body: SafeArea(child: body));
    return SafeArea(child: body);
  }

  Widget _buildGroupHeader(
    BuildContext context,
    AppState state,
    ServerGroup group,
    bool searching,
  ) {
    final l10n = L10nScope.of(context);
    final title = group.favorite
        ? l10n.favorites
        : group.subId.isEmpty
            ? l10n.manualGroup
            : (group.name.isEmpty
                ? l10n.subscriptionFallback
                : group.name);
    final canAuto =
        !group.favorite && group.subId.isNotEmpty && group.profiles.length > 1;
    final autoActive = canAuto && state.groupAuto.contains(group.subId);
    return _GroupHeader(
      group: group,
      title: title,
      count: group.profiles.length,
      collapsed: _isCollapsed(group, searching),
      onToggle: () => setState(() {
        final key = _key(group);
        if (!_collapsed.remove(key)) _collapsed.add(key);
      }),
      autoActive: autoActive,
      onAuto: canAuto
          ? () {
              state.setGroupAuto(group.subId, !autoActive);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(!autoActive
                    ? l10n.groupAutoOn(title)
                    : l10n.groupAutoOff(title)),
                behavior: SnackBarBehavior.floating,
                width: 340,
              ));
            }
          : null,
      // Favorites is a virtual view — deleting it would mean deleting every
      // favorited server across all profiles, so no bulk action here.
      onDelete: group.favorite
          ? null
          : () => _confirmDeleteGroup(context, state, group, title),
    );
  }

  Widget _buildGroupBlock(
    BuildContext context,
    AppState state,
    ServerGroup group,
    bool searching,
  ) {
    final collapsed = _isCollapsed(group, searching);
    return AnimatedSize(
      duration: WayMotion.medium,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: collapsed
          ? const SizedBox(width: double.infinity)
          : Column(
              children: [
                for (var j = 0; j < group.profiles.length; j++)
                  _Entrance(
                    index: j,
                    child: ProfileTile(
                      profile: group.profiles[j],
                      // Compare with the resolved selection (auto-group best
                      // or first-profile fallback) so the highlight always
                      // matches what connect() will actually use — including
                      // a group running fast-pick mode.
                      selected: group.profiles[j].id ==
                              state.effectiveProfile?.id &&
                          !state.autoSelect,
                      latency: state.latencies[group.profiles[j].id],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Lightweight slot descriptor for the grouped list:
/// 0 = auto tile, 1 = group header, 2 = group tile block.
class _Slot {
  final int kind;
  final int group;

  const _Slot.auto()
      : kind = 0,
        group = -1;
  const _Slot.header(this.group) : kind = 1;
  const _Slot.block(this.group) : kind = 2;
}

/// Section header of a server group: icon, the subscription's own VPN name,
/// a server count, a collapse chevron, a per-group fast-pick toggle and (for
/// deletable groups) a bulk delete button.
class _GroupHeader extends StatelessWidget {
  final ServerGroup group;
  final String title;
  final int count;
  final bool collapsed;
  final bool autoActive;
  final VoidCallback onToggle;
  final VoidCallback? onAuto;
  final VoidCallback? onDelete;

  const _GroupHeader({
    required this.group,
    required this.title,
    required this.count,
    required this.collapsed,
    required this.onToggle,
    this.autoActive = false,
    this.onAuto,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = group.favorite ? scheme.primary : scheme.onSurfaceVariant;
    final icon = group.favorite
        ? Icons.star_rounded
        : group.subId.isEmpty
            ? Icons.link_rounded
            : Icons.rss_feed_rounded;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 14, bottom: 4),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '$count ${l10n.serversPlural(count)}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  AnimatedRotation(
                    turns: collapsed ? -0.25 : 0,
                    duration: WayMotion.medium,
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (onAuto != null)
            IconButton(
              tooltip: l10n.groupAutoTooltip,
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: Icon(
                autoActive ? Icons.bolt_rounded : Icons.bolt_outlined,
                color: autoActive
                    ? scheme.primary
                    : scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              onPressed: onAuto,
            ),
          if (onDelete != null)
            IconButton(
              tooltip: l10n.delete,
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: scheme.error.withValues(alpha: 0.75),
              ),
              onPressed: onDelete,
            ),
        ],
      ),
    );
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
