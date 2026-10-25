import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config_builder.dart';
import '../../core/parser.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';

class RouteRulesScreen extends StatelessWidget {
  const RouteRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rulesEditor),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: l10n.ruleAdd,
            onPressed: () => _showRuleDialog(context),
          ),
        ],
      ),
      body: state.customRules.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.rulesHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: state.customRules.length,
              itemBuilder: (context, i) {
                final rule = state.customRules[i];
                return Card.filled(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Icon(_typeIcon(rule.type)),
                    title: Text(
                      rule.value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${_typeLabel(l10n, rule.type)} · ${_actionLabel(l10n, rule.action)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => state.removeRule(rule.id),
                    ),
                  ),
                );
              },
            ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'keyword':
        return Icons.text_fields_rounded;
      case 'domain':
        return Icons.language_rounded;
      case 'ip':
        return Icons.lan_rounded;
      case 'port':
        return Icons.settings_ethernet_rounded;
      default:
        return Icons.dns_rounded;
    }
  }

  String _typeLabel(L10n l10n, String type) {
    switch (type) {
      case 'keyword':
        return l10n.ruleTypeKeyword;
      case 'domain':
        return l10n.ruleTypeDomain;
      case 'ip':
        return l10n.ruleTypeIp;
      case 'port':
        return l10n.ruleTypePort;
      default:
        return l10n.ruleTypeSuffix;
    }
  }

  String _actionLabel(L10n l10n, String action) {
    switch (action) {
      case 'direct':
        return l10n.ruleDirect;
      case 'block':
        return l10n.ruleBlock;
      default:
        return l10n.ruleProxy;
    }
  }

  Future<void> _showRuleDialog(BuildContext context) async {
    final l10n = L10nScope.of(context);
    final state = context.read<AppState>();
    var type = 'suffix';
    var action = 'proxy';
    final valueController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.ruleAdd),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: InputDecoration(
                  labelText: l10n.ruleType,
                ),
                items: [
                  DropdownMenuItem(value: 'suffix', child: Text(l10n.ruleTypeSuffix)),
                  DropdownMenuItem(value: 'keyword', child: Text(l10n.ruleTypeKeyword)),
                  DropdownMenuItem(value: 'domain', child: Text(l10n.ruleTypeDomain)),
                  DropdownMenuItem(value: 'ip', child: Text(l10n.ruleTypeIp)),
                  DropdownMenuItem(value: 'port', child: Text(l10n.ruleTypePort)),
                ],
                onChanged: (v) => setState(() => type = v ?? 'suffix'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                decoration: InputDecoration(
                  labelText: l10n.ruleValue,
                  hintText: type == 'ip' ? '1.2.3.0/24' : 'example.com',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'proxy', label: Text(l10n.ruleProxy)),
                  ButtonSegment(value: 'direct', label: Text(l10n.ruleDirect)),
                  ButtonSegment(value: 'block', label: Text(l10n.ruleBlock)),
                ],
                selected: {action},
                onSelectionChanged: (s) => setState(() => action = s.first),
              ),
            ],
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
      ),
    );
    final value = valueController.text.trim();
    valueController.dispose();
    if (ok != true || value.isEmpty) return;
    state.addRule(RouteRule(
      id: LinkParser.genId(),
      type: type,
      value: value,
      action: action,
    ));
  }
}
