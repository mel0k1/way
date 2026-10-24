import 'package:flutter/material.dart';

import '../../core/profile.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import 'package:provider/provider.dart';

class ProfileTile extends StatelessWidget {
  final Profile profile;
  final bool selected;
  final int? latency;

  const ProfileTile({
    super.key,
    required this.profile,
    required this.selected,
    this.latency,
  });

  Color _latencyColor(ColorScheme scheme) {
    if (latency == null) return scheme.onSurfaceVariant;
    if (latency! < 200) return scheme.primary;
    if (latency! < 700) return scheme.tertiary;
    return scheme.error;
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

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = context.read<AppState>();
    final color = _latencyColor(scheme);

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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (latency != null)
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
                  '$latency ${l10n.ms}',
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
            PopupMenuButton<String>(
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
                } else if (value == 'chain') {
                  _showChainDialog(context, state, profile.id);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'chain',
                  child: Row(
                    children: [
                      const Icon(Icons.account_tree_rounded),
                      const SizedBox(width: 12),
                      Text(l10n.chainThrough),
                    ],
                  ),
                ),
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
          ],
        ),
      ),
    );
  }
}
