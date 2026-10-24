import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/formats.dart';
import '../../core/profile.dart';
import '../../l10n.dart';

Future<void> showQrExport(BuildContext context, Profile profile) async {
  final l10n = L10nScope.of(context);
  final link = LinkBuilder.build(profile);
  if (link == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.qrUnsupported),
      behavior: SnackBarBehavior.floating,
      width: 320,
    ));
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        profile.name,
        overflow: TextOverflow.ellipsis,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: link,
              version: QrVersions.auto,
              size: 240,
              gapless: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            link,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: link));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(l10n.copied),
                behavior: SnackBarBehavior.floating,
                width: 320,
              ));
            }
          },
          icon: const Icon(Icons.copy_rounded),
          label: Text(l10n.copy),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    ),
  );
}
