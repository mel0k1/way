import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/phone_import.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';

/// LAN import from a phone, Chumpy-style: a QR with the receiver URL, a
/// 6-digit PIN and a self-contained page on the phone side. The sheet
/// watches the server's state notifier and closes itself once the config
/// lands in the profile list — or the wallpaper is applied.
Future<void> showPhoneImport(BuildContext context, {bool wallpaper = false}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _PhoneImportSheet(wallpaper: wallpaper),
  );
}

class _PhoneImportSheet extends StatefulWidget {
  final bool wallpaper;

  const _PhoneImportSheet({this.wallpaper = false});

  @override
  State<_PhoneImportSheet> createState() => _PhoneImportSheetState();
}

class _PhoneImportSheetState extends State<_PhoneImportSheet> {
  bool _celebrated = false;
  late final AppState _appState = context.read<AppState>();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      _appState.startPhoneImport(wallpaper: widget.wallpaper);
    });
  }

  @override
  void dispose() {
    // A received session is already closed server-side; stop just in case
    // the sheet is dismissed mid-wait.
    _appState.stopPhoneImport();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final s = state.phoneImportState;
    final title = widget.wallpaper ? l10n.phoneWallpaper : l10n.phoneImport;
    final hint =
        widget.wallpaper ? l10n.phoneWallpaperHint : l10n.phoneImportHint;
    final sent = widget.wallpaper ? l10n.phoneWallpaperSent : l10n.phoneSent;

    if (s.phase == PhoneImportPhase.received && !_celebrated) {
      _celebrated = true;
      Future.microtask(() {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(sent),
          behavior: SnackBarBehavior.floating,
          width: 320,
        ));
        Navigator.of(context).pop();
      });
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 18),
            if (s.phase == PhoneImportPhase.waiting) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: scheme.surfaceContainerHigh,
                  ),
                  child: QrImageView(
                    data: s.url,
                    size: 220,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SelectableText(
                s.url,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: scheme.secondaryContainer,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.phonePin,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      s.pin,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            color: scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.phoneWaiting,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.close_rounded, size: 18),
                label: Text(l10n.phoneClose),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ] else if (s.phase == PhoneImportPhase.received) ...[
              const Center(child: Icon(Icons.check_circle_rounded, size: 44)),
              const SizedBox(height: 12),
              Text(sent, textAlign: TextAlign.center),
            ] else if (s.phase == PhoneImportPhase.expired ||
                s.phase == PhoneImportPhase.locked) ...[
              Center(
                child: Icon(Icons.schedule_rounded,
                    size: 44, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Text(l10n.phoneExpired, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(title),
                onPressed: () => _appState
                    .startPhoneImport(wallpaper: widget.wallpaper),
              ),
            ] else if (s.phase == PhoneImportPhase.failed) ...[
              Center(
                child: Icon(Icons.wifi_off_rounded,
                    size: 44, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Text(l10n.phoneFailed, textAlign: TextAlign.center),
            ] else ...[
              const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
