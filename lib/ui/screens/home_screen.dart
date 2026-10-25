import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../state/app_state.dart';
import 'servers_screen.dart';
import '../widgets/connect_button.dart';
import '../widgets/status_card.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    final profile = state.effectiveProfile;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const ConnectButton(),
              const SizedBox(height: 20),
              const StatusLabel(),
              const SizedBox(height: 32),
              const StatusCard(),
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
                        color: scheme.primaryContainer,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        state.autoSelect
                            ? Icons.bolt_rounded
                            : Icons.dns_rounded,
                        size: 22,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      state.autoSelect
                          ? l10n.autoFastest
                          : (profile?.name ?? l10n.navServers),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: profile != null
                        ? Text('${profile.server}:${profile.port}',
                            overflow: TextOverflow.ellipsis)
                        : Text(l10n.noServers),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        duration: const Duration(milliseconds: 200),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
