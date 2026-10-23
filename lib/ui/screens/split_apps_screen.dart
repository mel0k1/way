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
