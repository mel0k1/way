import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n.dart';
import '../../state/app_state.dart';
import 'package:provider/provider.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final ScrollController _scroll = ScrollController();
  int _lastCount = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the newest line visible, but never fights the reader: only snaps
  /// to the bottom when the view was already there (or on the first fill).
  void _follow(int count) {
    if (count == _lastCount) return;
    final nearBottom = !_scroll.hasClients ||
        _scroll.position.maxScrollExtent - _scroll.offset < 240;
    final firstFill = _lastCount == -1;
    _lastCount = count;
    if (!nearBottom && !firstFill) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.watch<AppState>();
    final coreLogs = state.coreLogTail();
    final lines = [...state.logLines, if (coreLogs.isNotEmpty) ...coreLogs];
    _follow(lines.length);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.logsTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.copy,
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: lines.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.copied)),
                    );
                  },
                ),
                IconButton(
                  tooltip: l10n.clear,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: state.clearLogs,
                ),
              ],
            ),
          ),
          Expanded(
            child: lines.isEmpty
                ? Center(child: Text(l10n.emptyLogs))
                : Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: lines.length,
                      itemBuilder: (context, i) => Text(
                        lines[i],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
