import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/subscriptions.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../screens/qr_scan_screen.dart';
import 'package:provider/provider.dart';

void showAddSheet(BuildContext context, String kind) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _AddSheet(kind: kind),
  );
}

class _AddSheet extends StatefulWidget {
  final String kind;

  const _AddSheet({required this.kind});

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final linkController = TextEditingController();
  final nameController = TextEditingController();
  final urlController = TextEditingController();

  @override
  void dispose() {
    linkController.dispose();
    nameController.dispose();
    urlController.dispose();
    super.dispose();
  }

  Future<void> _paste(TextEditingController controller) async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty && mounted) {
      controller.text = text;
    }
  }

  Future<void> _scanQr() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    context.read<AppState>().addFromLink(code.trim());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.read<AppState>();
    final isSub = widget.kind == 'sub';
    final padding = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isSub ? l10n.addSubscription : l10n.addServer,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (isSub) ...[
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.nameLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.urlLabel,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste_rounded),
                  tooltip: l10n.paste,
                  onPressed: () => _paste(urlController),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isEmpty) return;
                state.addSubscription(url, nameController.text.trim());
                Navigator.pop(context);
              },
              icon: const Icon(Icons.rss_feed_rounded),
              label: Text(l10n.save),
            ),
          ] else ...[
            TextField(
              controller: linkController,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                labelText: l10n.linkHint,
                border: const OutlineInputBorder(),
                suffixIcon: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.content_paste_rounded),
                      tooltip: l10n.paste,
                      onPressed: () => _paste(linkController),
                    ),
                    if (!state.isDesktop)
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        tooltip: l10n.scanQr,
                        onPressed: _scanQr,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final link = linkController.text.trim();
                if (link.isEmpty) return;
                state.addFromLink(link);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.link_rounded),
              label: Text(l10n.imported),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class SubscriptionTile extends StatelessWidget {
  final Subscription sub;

  const SubscriptionTile({super.key, required this.sub});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.read<AppState>();
    return ListTile(
      leading: const Icon(Icons.rss_feed_rounded),
      title: Text(sub.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${sub.count} ${l10n.entries} · ${sub.lastUpdate?.toString().substring(0, 16) ?? l10n.never}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => state.updateSubscription(sub),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => state.removeSubscription(sub.id),
          ),
        ],
      ),
    );
  }
}
