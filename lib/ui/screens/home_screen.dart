import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/vpn_bridge.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../motion.dart';
import 'servers_screen.dart';
import '../widgets/status_card.dart';
import '../widgets/status_plaque.dart';
import '../widgets/wavy_connect_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final profile = state.effectiveProfile;
    final phase = state.vpn.phase;
    final connected = phase == VpnPhase.connected;
    final error = state.vpn.error != null;
    final hour = DateTime.now().hour;
    final greeting = hour >= 5 && hour < 12
        ? l10n.greetingMorning
        : hour >= 12 && hour < 17
            ? l10n.greetingAfternoon
            : hour >= 17 && hour < 23
                ? l10n.greetingEvening
                : l10n.greetingNight;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: viewport.maxHeight - 28),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      Text(
                        l10n.appName,
                        style: text.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        greeting,
                        style: text.displayMedium?.copyWith(
                          letterSpacing: -1,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusChip(
                            label: switch (phase) {
                              VpnPhase.connected => l10n.connected,
                              VpnPhase.connecting => l10n.connecting,
                              VpnPhase.disconnecting => l10n.disconnecting,
                              VpnPhase.stopped => l10n.stopped,
                            },
                            active: connected,
                            error: error,
                          ),
                          if (connected) const _UptimeChip(),
                          if (state.isDesktop) const _ModeChip(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Squish(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ServersScreen(fullPage: true),
                          ),
                        ),
                        child: Card.filled(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: scheme.secondaryContainer,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                state.autoSelect
                                    ? Icons.bolt_rounded
                                    : Icons.dns_rounded,
                                size: 22,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                            title: Text(
                              state.autoSelect
                                  ? l10n.autoFastest
                                  : (profile?.name ?? l10n.navServers),
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium,
                            ),
                            subtitle: profile != null
                                ? Text(
                                    '${profile.server}:${profile.port}',
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Text(l10n.noServers),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                        ),
                      ),
                      if (error || state.isReconnecting) ...[
                        const SizedBox(height: 14),
                        const StatusPlaque(),
                      ],
                      const SizedBox(height: 16),
                      const StatusCard(),
                      const SizedBox(height: 16),
                      const WavyConnectBar(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String label;
  final Color? background;
  final Color? foreground;
  final VoidCallback? onTap;

  const _InfoChip({
    this.icon,
    this.leading,
    required this.label,
    this.background,
    this.foreground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = background ?? scheme.surfaceContainerHigh;
    final fg = foreground ?? scheme.onSurfaceVariant;
    return _Squish(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: bg,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 7),
            ] else if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool error;

  const _StatusChip({
    required this.label,
    required this.active,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = error
        ? scheme.errorContainer
        : active
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHigh;
    final fg = error
        ? scheme.onErrorContainer
        : active
            ? scheme.onSecondaryContainer
            : scheme.onSurfaceVariant;
    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? fg : Colors.transparent,
        border: active ? null : Border.all(color: fg, width: 1.5),
      ),
    );
    return _InfoChip(
      leading: dot,
      label: label,
      background: bg,
      foreground: fg,
    );
  }
}

class _UptimeChip extends StatefulWidget {
  const _UptimeChip();

  @override
  State<_UptimeChip> createState() => _UptimeChipState();
}

class _UptimeChipState extends State<_UptimeChip> {
  late final Timer _timer = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  String _hms(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return _InfoChip(
      icon: Icons.schedule_rounded,
      label: _hms(state.uptime),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip();

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.watch<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    return _InfoChip(
      icon: state.preferTun
          ? Icons.vpn_lock_rounded
          : Icons.lan_rounded,
      label: state.preferTun ? l10n.modeTun : l10n.modeProxy,
      background: state.preferTun
          ? Theme.of(context).colorScheme.tertiaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHigh,
      foreground: state.preferTun
          ? Theme.of(context).colorScheme.onTertiaryContainer
          : null,
      onTap: () async {
        final ok = await state.toggleTunMode(!state.preferTun);
        if (!ok) {
          messenger.showSnackBar(SnackBar(
            content: Text(l10n.tunForcedByKillswitch),
            behavior: SnackBarBehavior.floating,
            width: 340,
          ));
        }
      },
    );
  }
}

/// Press feedback with a slight squish — an expressive touch for tappable
/// cards on the home screen.
class _Squish extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _Squish({required this.child, this.onTap});

  @override
  State<_Squish> createState() => _SquishState();
}

class _SquishState extends State<_Squish> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: WayMotion.fast,
        curve: _pressed ? Curves.easeOutCubic : WayMotion.springy,
        child: widget.child,
      ),
    );
  }
}
