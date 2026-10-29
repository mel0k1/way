import 'package:flutter/material.dart';

import '../../core/uwp.dart';
import '../../l10n.dart';

/// Windows-only: exempt Microsoft Store apps from loopback isolation so they
/// can use Way's local proxy inbound (Karing's
/// uwp_loopback_exemption_windows_screen).
class UwpLoopbackScreen extends StatefulWidget {
  const UwpLoopbackScreen({super.key});

  @override
  State<UwpLoopbackScreen> createState() => _UwpLoopbackScreenState();
}

class _UwpLoopbackScreenState extends State<UwpLoopbackScreen> {
  List<UwpApp> _apps = [];
  Set<String> _exempted = {};
  final Set<String> _checked = {};
  final TextEditingController _search = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([UwpLoopback.installed(), UwpLoopback.exempted()]);
    if (!mounted) return;
    setState(() {
      _apps = results[0] as List<UwpApp>;
      _exempted = results[1] as Set<String>;
      _checked
        ..clear()
        ..addAll(_exempted);
      _loading = false;
    });
  }

  Future<void> _save() async {
    final l10n = L10nScope.of(context);
    setState(() => _saving = true);
    final toAdd = _checked.difference(_exempted);
    final toRemove = _exempted.difference(_checked);
    var failed = 0;
    for (final f in toAdd) {
      if (!await UwpLoopback.exempt(f)) failed++;
    }
    for (final f in toRemove) {
      if (!await UwpLoopback.unexempt(f)) failed++;
    }
    await _reload();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(failed > 0 ? l10n.uwpNeedAdmin : l10n.uwpSaved),
      behavior: SnackBarBehavior.floating,
      width: 340,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final q = _search.text.trim().toLowerCase();
    final apps = q.isEmpty
        ? _apps
        : _apps
            .where((a) =>
                a.name.toLowerCase().contains(q) ||
                a.family.toLowerCase().contains(q))
            .toList();
    final allChecked =
        _apps.isNotEmpty && _apps.every((a) => _checked.contains(a.family));
    final noneChecked = _apps.every((a) => !_checked.contains(a.family));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.uwpLoopback)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                l10n.uwpHint,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        hintText: l10n.searchApps,
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide:
                              BorderSide(color: scheme.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  Checkbox(
                    tristate: true,
                    value: allChecked
                        ? true
                        : noneChecked
                            ? false
                            : null,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        for (final a in _apps) {
                          _checked.add(a.family);
                        }
                      } else {
                        _checked.clear();
                      }
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(strokeWidth: 2.5),
                          const SizedBox(height: 12),
                          Text(l10n.uwpLoading),
                        ],
                      ),
                    )
                  : _apps.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              _error ?? l10n.uwpEmpty,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: scheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                          itemCount: apps.length,
                          itemBuilder: (context, i) {
                            final a = apps[i];
                            return CheckboxListTile(
                              value: _checked.contains(a.family),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _checked.add(a.family);
                                } else {
                                  _checked.remove(a.family);
                                }
                              }),
                              title: Text(
                                a.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                a.family,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 10),
                              ),
                            );
                          },
                        ),
            ),
            if (_apps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_checked.length} / ${_apps.length}',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2))
                          : const Icon(Icons.done_all_rounded),
                      label: Text(l10n.uwpSave),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
