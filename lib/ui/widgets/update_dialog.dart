import 'package:flutter/material.dart';

import '../../core/updates.dart';
import '../../core/version.dart';
import '../../l10n.dart';

Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  final l10n = L10nScope.of(context);
  final url = info.downloadUrl ?? releasesPage;
  final notes = info.notes?.trim();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.system_update_alt_rounded),
      title: Text('${l10n.updateAvailable} · v${info.version}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.currentVersion}: $appVersion',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(l10n.whatsNew, style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                notes == null || notes.isEmpty ? '—' : notes,
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.later),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.download_rounded),
          label: Text(l10n.download),
          onPressed: () {
            Navigator.of(ctx).pop();
            UpdateChecker.openUrl(url);
          },
        ),
      ],
    ),
  );
}
