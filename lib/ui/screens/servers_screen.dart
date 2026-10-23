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
                  itemCount: state.profiles.length,
                  itemBuilder: (context, i) => ProfileTile(
                    profile: state.profiles[i],
                    selected: state.profiles[i].id == state.selectedId,
                  ),
                ),
        ),
      ],
    );

    if (fullPage) return Scaffold(body: SafeArea(child: body));
    return SafeArea(child: body);
  }
}
