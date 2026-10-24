import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formats.dart';
import '../../core/parser.dart';
import '../../core/profile.dart';
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
  final jsonController = TextEditingController();
  final manualServer = TextEditingController();
  final manualPort = TextEditingController();
  final manualSecret = TextEditingController();
  final manualSni = TextEditingController();
  final manualName = TextEditingController();
  String manualType = 'vless';
  String mode = 'link';
  bool warpBusy = false;

  @override
  void dispose() {
    linkController.dispose();
    nameController.dispose();
    urlController.dispose();
    jsonController.dispose();
    manualServer.dispose();
    manualPort.dispose();
    manualSecret.dispose();
    manualSni.dispose();
    manualName.dispose();
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

  void _addManual() {
    final l10n = L10nScope.of(context);
    final state = context.read<AppState>();
    final server = manualServer.text.trim();
    final port = int.tryParse(manualPort.text.trim()) ?? 0;
    final secret = manualSecret.text.trim();
    if (server.isEmpty || port <= 0 || secret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.invalidInput),
        behavior: SnackBarBehavior.floating,
        width: 320,
      ));
      return;
    }
    final isUuid = manualType == 'vless' || manualType == 'vmess' || manualType == 'tuic';
    final p = Profile(
      id: LinkParser.genId(),
      name: manualName.text.trim().isEmpty ? '$server:$port' : manualName.text.trim(),
      protocol: manualType,
      server: server,
      port: port,
      uuid: isUuid ? secret : null,
      password: isUuid ? null : secret,
      method: manualType == 'shadowsocks' ? 'aes-256-gcm' : null,
      security: manualType == 'vmess' ? 'auto' : null,
      congestion: manualType == 'tuic' ? 'bbr' : null,
      sni: manualSni.text.trim(),
      alpn: manualType == 'tuic' ? 'h3' : null,
    );
    if (manualType == 'tuic') p.password = '';
    state.addProfile(p);
    Navigator.pop(context);
  }

  void _addJson() {
    final l10n = L10nScope.of(context);
    final state = context.read<AppState>();
    final text = jsonController.text.trim();
    if (text.isEmpty) return;
    final parsed = SubFormats.parseAny(text);
    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.errParse),
        behavior: SnackBarBehavior.floating,
        width: 320,
      ));
      return;
    }
    state.addFromLink(text);
    Navigator.pop(context);
  }

  Future<void> _addWarp() async {
    final l10n = L10nScope.of(context);
    final state = context.read<AppState>();
    setState(() => warpBusy = true);
    try {
      await state.addWarp();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.warpAdded),
          behavior: SnackBarBehavior.floating,
          width: 320,
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => warpBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.warpFailed),
          behavior: SnackBarBehavior.floating,
          width: 320,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.read<AppState>();
    final isSub = widget.kind == 'sub';
    final padding = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, padding.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isSub ? l10n.addSubscription : l10n.addServer,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (!isSub) ...[
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'link', label: Text(l10n.addModeLink)),
                  ButtonSegment(value: 'manual', label: Text(l10n.addModeManual)),
                  const ButtonSegment(value: 'json', label: Text('JSON')),
                ],
                selected: {mode},
                onSelectionChanged: (s) => setState(() => mode = s.first),
              ),
              const SizedBox(height: 12),
            ],
            if (isSub) ...[
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.nameLabel,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l10n.urlLabel,
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
            ] else if (mode == 'link') ...[
              TextField(
                controller: linkController,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: l10n.linkHint,
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
            ] else if (mode == 'manual') ...[
              TextField(
                controller: manualName,
                decoration: InputDecoration(
                  labelText: l10n.nameLabel,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: manualType,
                decoration: InputDecoration(
                  labelText: l10n.manualType,
                ),
                items: const [
                  DropdownMenuItem(value: 'vless', child: Text('VLESS')),
                  DropdownMenuItem(value: 'vmess', child: Text('VMess')),
                  DropdownMenuItem(value: 'trojan', child: Text('Trojan')),
                  DropdownMenuItem(value: 'shadowsocks', child: Text('Shadowsocks')),
                  DropdownMenuItem(value: 'hysteria2', child: Text('Hysteria2')),
                  DropdownMenuItem(value: 'tuic', child: Text('TUIC')),
                  DropdownMenuItem(value: 'anytls', child: Text('AnyTLS')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => manualType = v);
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: manualServer,
                      decoration: InputDecoration(
                        labelText: l10n.manualServer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: manualPort,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.manualPort,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: manualSecret,
                decoration: InputDecoration(
                  labelText: l10n.manualSecret,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: manualSni,
                decoration: InputDecoration(
                  labelText: l10n.manualSni,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _addManual,
                icon: const Icon(Icons.dns_rounded),
                label: Text(l10n.save),
              ),
            ] else ...[
              TextField(
                controller: jsonController,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: l10n.addModeJson,
                  helperText: l10n.jsonHint,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_rounded),
                    tooltip: l10n.paste,
                    onPressed: () => _paste(jsonController),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _addJson,
                icon: const Icon(Icons.data_object_rounded),
                label: Text(l10n.imported),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: warpBusy ? null : _addWarp,
              icon: warpBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_rounded),
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.warp),
                  Text(
                    l10n.warpHint,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
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
