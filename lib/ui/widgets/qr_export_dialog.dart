import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/formats.dart';
import '../../core/profile.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';

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
  await _showQrDialog(
    context: context,
    title: profile.name,
    link: link,
    footer: link,
  );
}

/// QR transfer code: `way://import/<base64url of newline-joined links>`.
/// Carries every profile plus subscription URLs to the phone in one scan.
Future<void> showQrTransfer(BuildContext context, AppState state) async {
  final l10n = L10nScope.of(context);
  final lines = <String>[];
  for (final sub in state.subs) {
    if (sub.url.startsWith('http')) lines.add(sub.url);
  }
  for (final p in state.profiles) {
    final link = LinkBuilder.build(p);
    if (link != null) lines.add(link);
  }
  if (lines.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.nothingToTransfer),
      behavior: SnackBarBehavior.floating,
      width: 320,
    ));
    return;
  }
  final payload =
      base64Url.encode(utf8.encode(lines.join('\n'))).replaceAll('=', '');
  final link = 'way://import/$payload';
  if (link.length > 2600) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.qrTooBig),
      behavior: SnackBarBehavior.floating,
      width: 340,
    ));
    return;
  }
  await _showQrDialog(
    context: context,
    title: l10n.transferQr,
    link: link,
    footer: l10n.transferQrHint,
  );
}

Future<void> _showQrDialog({
  required BuildContext context,
  required String title,
  required String link,
  required String footer,
}) async {
  final l10n = L10nScope.of(context);
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        title,
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
            footer,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
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
