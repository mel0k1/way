import 'package:flutter/material.dart';

import '../../core/vpn_bridge.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import 'package:provider/provider.dart';

class ConnectButton extends StatelessWidget {
  const ConnectButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final connected = state.vpn.phase == VpnPhase.connected;
    final busy = state.vpn.phase == VpnPhase.connecting ||
        state.vpn.phase == VpnPhase.disconnecting;

    return GestureDetector(
      onTap: () {
        final app = context.read<AppState>();
        if (connected) {
          app.disconnect();
        } else if (!busy) {
          app.connect();
        }
      },
      child: SizedBox(
        width: 208,
        height: 208,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 204,
              height: 204,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(64),
                border: Border.all(
                  color: connected
                      ? scheme.primary.withValues(alpha: 0.45)
                      : scheme.outlineVariant.withValues(alpha: 0.55),
                  width: 2,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: connected ? 168 : 156,
              height: connected ? 168 : 156,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(52),
                color: connected
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: connected
                        ? scheme.primary.withValues(alpha: 0.35)
                        : scheme.shadow.withValues(alpha: 0.08),
                    blurRadius: connected ? 42 : 16,
                    spreadRadius: connected ? 6 : 2,
                  ),
                ],
              ),
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.all(44),
                      child: CircularProgressIndicator(
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                        color: connected
                            ? scheme.onPrimary
                            : scheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.power_settings_new_rounded,
                      size: 64,
                      color: connected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusLabel extends StatelessWidget {
  const StatusLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.watch<AppState>();
    final text = switch (state.vpn.phase) {
      VpnPhase.connected => l10n.connected,
      VpnPhase.connecting => l10n.connecting,
      VpnPhase.disconnecting => l10n.disconnecting,
      VpnPhase.stopped => l10n.stopped,
    };
    if (state.vpn.error != null) {
      return Text(
        l10n.errorText(state.vpn.error),
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      );
    }
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}
