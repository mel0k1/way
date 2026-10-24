import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../state/app_state.dart';

class SplitAppsScreen extends StatefulWidget {
  const SplitAppsScreen({super.key});

  @override
  State<SplitAppsScreen> createState() => _SplitAppsScreenState();
}

class _SplitAppsScreenState extends State<SplitAppsScreen> {
  static const _channel = MethodChannel('way/core');
  static const _popular = [
    'com.android.chrome',
    'org.mozilla.firefox',
    'com.brave.browser',
    'com.opera.browser',
    'com.microsoft.emmx',
    'com.sec.android.app.sbrowser',
    'org.telegram.messenger',
    'com.whatsapp',
    'com.viber.voip',
    'org.thoughtcrime.securesms',
    'com.instagram.android',
    'com.google.android.youtube',
    'com.discord',
    'com.twitter.android',
  ];
  List<Map<String, String>> _apps = [];
  Set<String> _selected = {};
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _selected = Set.of(state.splitApps);
    _load();
  }

  Future<void> _load() async {
    List<Map<String, String>> apps = [];
    try {
      final raw = await _channel.invokeListMethod('apps');
      if (raw != null) {
        apps = raw
            .whereType<Map>()
            .map((e) => {
                  'label': '${e['label'] ?? e['package']}',
                  'package': '${e['package'] ?? ''}',
                })
            .toList()
          ..sort((a, b) => a['label']!.toLowerCase().compareTo(b['label']!.toLowerCase()));
      }
    } on PlatformException {
      apps = [];
    }
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  void _autoPick() {
    final installed = _apps.map((a) => a['package']).toSet();
    final found = _popular.where(installed.contains).toSet();
    setState(() => _selected.addAll(found));
    if (!mounted) return;
    final l10n = L10nScope.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.autoPickDone(found.length)),
      behavior: SnackBarBehavior.floating,
      width: 320,
    ));
  }

  void _exportList() {
    final text = _selected.toList()..sort();
    Clipboard.setData(ClipboardData(text: text.join('\n')));
    final l10n = L10nScope.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.copied),
      behavior: SnackBarBehavior.floating,
      width: 320,
    ));
  }

  Future<void> _importList() async {
    final l10n = L10nScope.of(context);
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.appsImport),
        content: TextField(
          controller: controller,
          maxLines: 6,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.appsImportHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (ok != true) {
      controller.dispose();
      return;
    }
    final raw = controller.text;
    controller.dispose();
    final packages = raw
        .split(RegExp(r'[\s,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    setState(() => _selected.addAll(packages));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.appsImported(packages.length)),
      behavior: SnackBarBehavior.floating,
      width: 320,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final query = _query.toLowerCase();
    final filtered = _apps
        .where((a) =>
            query.isEmpty ||
            a['label']!.toLowerCase().contains(query) ||
            a['package']!.contains(query))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.splitPickApps),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: () {
              context.read<AppState>().setSplitApps(_selected.toList());
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: l10n.searchApps,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text('${_selected.length} ${l10n.splitSelected}'),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                        tooltip: l10n.autoPick,
                        onPressed: _autoPick,
                      ),
                      IconButton(
                        icon: const Icon(Icons.ios_share_rounded, size: 20),
                        tooltip: l10n.appsExport,
                        onPressed: _exportList,
                      ),
                      IconButton(
                        icon: const Icon(Icons.paste_rounded, size: 20),
                        tooltip: l10n.appsImport,
                        onPressed: _importList,
                      ),
                      TextButton(
                        onPressed: () => setState(() => _selected.clear()),
                        child: Text(l10n.clear),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(child: Text(l10n.noAppsFound))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final app = filtered[i];
                            final pkg = app['package']!;
                            return CheckboxListTile(
                              value: _selected.contains(pkg),
                              title: Text(app['label']!,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(pkg,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall),
                              onChanged: (on) => setState(() {
                                if (on == true) {
                                  _selected.add(pkg);
                                } else {
                                  _selected.remove(pkg);
                                }
                              }),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
