import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/config_builder.dart';
import '../../core/parser.dart';
import '../../core/profile.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../motion.dart';
import 'package:provider/provider.dart';
import 'qr_export_dialog.dart';

class ProfileTile extends StatefulWidget {
  final Profile profile;
  final bool selected;
  final int? latency;

  const ProfileTile({
    super.key,
    required this.profile,
    required this.selected,
    this.latency,
  });

  @override
  State<ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<ProfileTile> {
  /// Whether the stretched details card is open. Follows [ProfileTile.selected]
  /// automatically, but the user can collapse it with a second tap.
  bool _expanded = false;

  Color _latencyColor(ColorScheme scheme) {
    final latency = widget.latency;
    if (latency == null) return scheme.onSurfaceVariant;
    if (latency < 200) return scheme.primary;
    if (latency < 700) return scheme.tertiary;
    return scheme.error;
  }

  @override
  void didUpdateWidget(covariant ProfileTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _expanded = widget.selected;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final profile = widget.profile;
    final selected = widget.selected;
    final color = _latencyColor(scheme);

    Profile? chain;
    if (profile.chainTo?.isNotEmpty == true) {
      for (final p in state.profiles) {
        if (p.id == profile.chainTo) chain = p;
      }
    }

    return Card.filled(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: selected ? scheme.primaryContainer : null,
      child: Column(
        children: [
          GestureDetector(
            onLongPressStart: (details) =>
                _showContextMenu(context, state, details.globalPosition),
            child: ListTile(
            onTap: () {
              if (selected) {
                setState(() => _expanded = !_expanded);
              } else {
                state.select(profile.id);
              }
            },
            leading: _LatencyBadge(
              label: profile.protocolLabel,
              latency: widget.latency,
              color: color,
              selected: selected,
              scheme: scheme,
            ),
            title: Text(
              profile.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chain != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree_rounded,
                          size: 13, color: scheme.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          chain.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                Text(
                  '${profile.server}:${profile.port}',
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (profile.favorite)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ),
                if (widget.latency != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: color.withValues(alpha: 0.14),
                    ),
                    child: Text(
                      '${widget.latency} ${l10n.ms}',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (state.latencyTesting)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                AnimatedRotation(
                  turns: _expanded && selected ? 0.5 : 0.0,
                  duration: WayMotion.medium,
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ),
          // Container transform: the tile stretches into a details card once
          // selected; a second tap folds it back.
          AnimatedSize(
            duration: WayMotion.medium,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded && selected
                ? _DetailsBody(
                    profile: profile,
                    chain: chain,
                    state: state,
                    scheme: scheme,
                    l10n: l10n,
                    onMenu: (value) =>
                        _handleMenu(context, state, value),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// Classic long-press menu — the same actions as the expanded card, for
  /// power users on big subscription lists.
  Future<void> _showContextMenu(
    BuildContext context,
    AppState state,
    Offset globalPosition,
  ) async {
    final l10n = L10nScope.of(context);
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(globalPosition);
    final profile = widget.profile;
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        local & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'fav',
          child: Row(children: [
            Icon(profile.favorite
                ? Icons.star_outline_rounded
                : Icons.star_rounded),
            const SizedBox(width: 12),
            Text(profile.favorite ? l10n.removeFavorite : l10n.addFavorite),
          ]),
        ),
        PopupMenuItem(
          value: 'qr',
          child: Row(children: [
            const Icon(Icons.qr_code_rounded),
            const SizedBox(width: 12),
            Text(l10n.showQr),
          ]),
        ),
        PopupMenuItem(
          value: 'bypass',
          child: Row(children: [
            const Icon(Icons.language_rounded),
            const SizedBox(width: 12),
            Text(l10n.bypassSite),
          ]),
        ),
        PopupMenuItem(
          value: 'chain',
          child: Row(children: [
            const Icon(Icons.account_tree_rounded),
            const SizedBox(width: 12),
            Text(l10n.chainThrough),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline_rounded),
            const SizedBox(width: 12),
            Text(l10n.delete),
          ]),
        ),
      ],
    );
    if (value == null || !context.mounted) return;
    _handleMenu(context, state, value);
  }

  void _handleMenu(BuildContext context, AppState state, String value) {
    if (value == 'fav') {
      state.toggleFavorite(widget.profile.id);
    } else if (value == 'delete') {
      _confirmDelete(context, state);
    } else if (value == 'chain') {
      _showChainDialog(context, state, widget.profile.id);
    } else if (value == 'qr') {
      showQrExport(context, widget.profile);
    } else if (value == 'bypass') {
      _showBypassDialog(context, state);
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppState state) async {
    final l10n = L10nScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteConfirm),
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
    if (ok == true) state.removeProfile(widget.profile.id);
  }

  void _showBypassDialog(BuildContext context, AppState state) {
    final l10n = L10nScope.of(context);
    final controller = TextEditingController();
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.language_rounded),
        title: Text(l10n.bypassSite),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.bypassSiteExplain,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.bypassSiteLabel,
                hintText: l10n.bypassSiteHint,
                prefixIcon: const Icon(Icons.public_rounded, size: 20),
              ),
              onSubmitted: (_) => Navigator.pop(context, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    ).then((ok) {
      final raw = controller.text.trim().toLowerCase();
      controller.dispose();
      if (ok != true) return;
      // Accept full URLs too: https://example.com/page → example.com.
      final domain = raw
          .replaceFirst(RegExp(r'^[a-z0-9]+://'), '')
          .split('/')
          .first
          .split(':')
          .first
          .trim();
      if (domain.isEmpty || domain.contains(' ')) return;
      final exists = state.customRules.any(
        (r) => r.type == 'suffix' && r.value == domain,
      );
      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.bypassSiteExists),
          behavior: SnackBarBehavior.floating,
          width: 320,
        ));
        return;
      }
      state.addRule(RouteRule(
        id: LinkParser.genId(),
        type: 'suffix',
        value: domain,
        action: 'direct',
      ));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.bypassSiteDone(domain)),
        behavior: SnackBarBehavior.floating,
        width: 320,
      ));
    });
  }

  void _showChainDialog(BuildContext context, AppState state, String profileId) {
    final l10n = L10nScope.of(context);
    final candidates = state.engineProfiles
        .where((p) => p.id != profileId)
        .toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.chainHint),
        behavior: SnackBarBehavior.floating,
        width: 320,
      ));
      return;
    }
    final current = state.profiles
        .where((p) => p.id == profileId)
        .map((p) => p.chainTo)
        .firstOrNull;
    String? target = current;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.chainThrough),
          content: SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: [
                RadioGroup<String?>(
                  groupValue: target,
                  onChanged: (v) => setState(() => target = v),
                  child: Column(
                    children: [
                      RadioListTile<String?>(
                        value: null,
                        title: Text(l10n.chainNone),
                      ),
                      for (final c in candidates)
                        RadioListTile<String?>(
                          value: c.id,
                          title: Text(
                            c.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${c.server}:${c.port}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                state.setChain(profileId, target);
                Navigator.pop(context);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

/// Protocol badge wrapped in a mini latency gauge: a 270° arc whose fill
/// reflects ping quality and whose color encodes the latency bucket.
class _LatencyBadge extends StatelessWidget {
  final String label;
  final int? latency;
  final Color color;
  final bool selected;
  final ColorScheme scheme;

  const _LatencyBadge({
    required this.label,
    required this.latency,
    required this.color,
    required this.selected,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    // Quality 0..1 — 1200ms+ reads as an empty gauge.
    final value = latency == null
        ? 0.0
        : 1.0 - (latency! / 1200).clamp(0.0, 1.0);
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (latency != null)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
                duration: WayMotion.slow,
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => CustomPaint(
                  painter: _GaugeArcPainter(value: v, color: color),
                ),
              ),
            )
          else
            Positioned.fill(
              child: CustomPaint(
                painter: _GaugeArcPainter(
                  value: 0,
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                  trackOnly: true,
                ),
              ),
            ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected ? scheme.primary : scheme.surfaceContainerHighest,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 270° mini gauge used by [_LatencyBadge]. Starts top-left, sweeps clockwise,
/// leaves a breathing gap at the top.
class _GaugeArcPainter extends CustomPainter {
  final double value;
  final Color color;
  final bool trackOnly;

  _GaugeArcPainter({
    required this.value,
    required this.color,
    this.trackOnly = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi * 0.75;
    const sweep = math.pi * 1.5;

    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: trackOnly ? 1 : 0.22),
    );
    final v = value.clamp(0.0, 1.0);
    if (trackOnly || v <= 0.01) return;
    canvas.drawArc(
      rect,
      start,
      sweep * v,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_GaugeArcPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.trackOnly != trackOnly;
}

/// Expanded body of the container transform: raw connection details plus the
/// quick actions that used to live only in the popup menu.
class _DetailsBody extends StatelessWidget {
  final Profile profile;
  final Profile? chain;
  final AppState state;
  final ColorScheme scheme;
  final L10n l10n;
  final void Function(String value) onMenu;

  const _DetailsBody({
    required this.profile,
    required this.chain,
    required this.state,
    required this.scheme,
    required this.l10n,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      profile.protocolLabel,
      if (profile.network?.isNotEmpty == true) profile.network!.toUpperCase(),
      if (profile.security == 'tls' || profile.sni?.isNotEmpty == true)
        'TLS'
      else if (profile.insecure)
        'insecure',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: WayMotion.medium,
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(
              height: 10,
              thickness: 0.8,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.14),
            ),
            _DetailRow(
              icon: Icons.dns_rounded,
              text: '${profile.server}:${profile.port}',
              scheme: scheme,
              mono: true,
            ),
            if (meta.isNotEmpty)
              _DetailRow(icon: Icons.lock_outline_rounded, text: meta, scheme: scheme),
            if (chain != null)
              _DetailRow(
                icon: Icons.account_tree_rounded,
                text: '${l10n.chainThrough}: ${chain!.name}',
                scheme: scheme,
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                _ActionIcon(
                  tooltip: profile.favorite
                      ? l10n.removeFavorite
                      : l10n.addFavorite,
                  icon: profile.favorite
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  scheme: scheme,
                  onTap: () => onMenu('fav'),
                ),
                _ActionIcon(
                  tooltip: l10n.showQr,
                  icon: Icons.qr_code_rounded,
                  scheme: scheme,
                  onTap: () => onMenu('qr'),
                ),
                _ActionIcon(
                  tooltip: l10n.bypassSite,
                  icon: Icons.language_rounded,
                  scheme: scheme,
                  onTap: () => onMenu('bypass'),
                ),
                _ActionIcon(
                  tooltip: l10n.chainThrough,
                  icon: Icons.account_tree_rounded,
                  scheme: scheme,
                  onTap: () => onMenu('chain'),
                ),
                const Spacer(),
                _ActionIcon(
                  tooltip: l10n.delete,
                  icon: Icons.delete_outline_rounded,
                  scheme: scheme,
                  error: true,
                  onTap: () => onMenu('delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme scheme;
  final bool mono;

  const _DetailRow({
    required this.icon,
    required this.text,
    required this.scheme,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: scheme.onPrimaryContainer.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontFeatures: mono
                    ? const [FontFeature.tabularFigures()]
                    : null,
                letterSpacing: mono ? 0.1 : null,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final bool error;

  const _ActionIcon({
    required this.tooltip,
    required this.icon,
    required this.scheme,
    required this.onTap,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      color: error
          ? scheme.error
          : scheme.onPrimaryContainer.withValues(alpha: 0.85),
      icon: Icon(icon),
      onPressed: onTap,
    );
  }
}
