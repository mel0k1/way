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

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const ConnectButton(),
              const SizedBox(height: 20),
              const StatusLabel(),
              const SizedBox(height: 32),
              const StatusCard(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ServersScreen(fullPage: true),
                    ),
                  ),
                  icon: const Icon(Icons.dns_rounded),
                  label: Text(
                    state.selected?.name ?? l10n.navServers,
                    overflow: TextOverflow.ellipsis,
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
