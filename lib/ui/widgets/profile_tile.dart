import 'package:flutter/material.dart';

import '../../core/profile.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import 'package:provider/provider.dart';

class ProfileTile extends StatelessWidget {
  final Profile profile;
  final bool selected;

  const ProfileTile({super.key, required this.profile, required this.selected});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = context.read<AppState>();

    return Card.filled(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: selected ? scheme.primaryContainer : null,
      child: ListTile(
        onTap: () => state.select(profile.id),
        leading: CircleAvatar(
          backgroundColor: selected
              ? scheme.primary
              : scheme.surfaceContainerHighest,
          foregroundColor: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          child: Text(
            profile.protocolLabel,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          profile.name,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${profile.server}:${profile.port}',
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'delete') {
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
              if (ok == true) state.removeProfile(profile.id);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded),
                  const SizedBox(width: 12),
                  Text(l10n.delete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
