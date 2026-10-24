import 'package:flutter/material.dart';

import '../../core/vpn_bridge.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import 'package:provider/provider.dart';

class ConnectButton extends StatefulWidget {
  const ConnectButton({super.key});

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  bool _pressed = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _tap(bool connected, bool busy) {
    final app = context.read<AppState>();
    if (connected) {
      app.disconnect();
    } else if (!busy) {
      app.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final connected = state.vpn.phase == VpnPhase.connected;
    final busy = state.vpn.phase == VpnPhase.connecting ||
        state.vpn.phase == VpnPhase.disconnecting;

    if (connected && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!connected && _pulse.isAnimating) {
      _pulse.stop();
    }

    return GestureDetector(
      onTap: () => _tap(connected, busy),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Easing.emphasizedDecelerate,
        child: SizedBox(
          width: 216,
          height: 216,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (connected) ...[
                _PulseRing(controller: _pulse, delay: 0, color: scheme.primary),
                _PulseRing(
                    controller: _pulse,
                    delay: 0.5,
                    color: scheme.primary),
              ],
              Container(
                width: 204,
                height: 204,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: connected
                        ? scheme.primary.withValues(alpha: 0.45)
                        : scheme.outlineVariant.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Easing.standard,
                width: connected ? 176 : 168,
                height: connected ? 176 : 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected
                      ? scheme.primary
                      : scheme.surfaceContainerHigh,
                  border: Border.all(
                    color: connected ? scheme.surface : Colors.transparent,
                    width: 8,
                  ),
                  boxShadow: [
                    if (connected)
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.32),
                        blurRadius: 44,
                        spreadRadius: 4,
                      ),
                  ],
                ),
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(48),
                        child: CircularProgressIndicator(
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          color:
                              connected ? scheme.onPrimary : scheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.power_settings_new_rounded,
                        size: 62,
                        color: connected
                            ? scheme.onPrimary
                            : scheme.primary,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Color color;

  const _PulseRing({
    required this.controller,
    required this.delay,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (controller.value - delay).clamp(0.0, 1.0) / (1 - delay);
        final eased = Curves.easeOut.transform(t);
        return Container(
          width: 176 + 96 * eased,
          height: 176 + 96 * eased,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.30 * (1 - eased)),
              width: 2.5,
            ),
          ),
        );
      },
    );
  }
}

class StatusLabel extends StatelessWidget {
  const StatusLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
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
          color: scheme.error,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      );
    }
    final connected = state.vpn.phase == VpnPhase.connected;
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: connected ? scheme.primary : scheme.onSurfaceVariant,
          ),
    );
  }
}
