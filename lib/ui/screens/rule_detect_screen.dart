import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/connections.dart';
import '../../core/route_detect.dart';
import '../../core/vpn_bridge.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';

/// "Where does a domain go?" (Karing's diversion_rule_detect_screen): replays
/// Way's routing pipeline client-side and, when the VPN is up, adds live
/// evidence from actual connections.
class RuleDetectScreen extends StatefulWidget {
  const RuleDetectScreen({super.key});

  @override
  State<RuleDetectScreen> createState() => _RuleDetectScreenState();
}

class _RuleDetectScreenState extends State<RuleDetectScreen> {
  final TextEditingController _input = TextEditingController();
  final ConnectionsPoller _poller = ConnectionsPoller();
  DetectResult? _result;
  String? _inputError;
  bool _checking = false;
  List<LiveConnection>? _live;
  bool _liveOff = false;

  @override
  void dispose() {
    _input.dispose();
    _poller.dispose();
    super.dispose();
  }

  Future<void> _detect() async {
    final l10n = L10nScope.of(context);
    final state = context.read<AppState>();
    final raw = _input.text.trim();
    final domain = RouteDetect.normalize(raw);
    if (domain.isEmpty) {
      setState(() {
        _inputError = l10n.ruleDetectInvalid;
        _result = null;
        _live = null;
        _liveOff = false;
      });
      return;
    }
    setState(() {
      _inputError = null;
      _result = RouteDetect.run(raw, state.routingSettings);
      _checking = true;
      _live = null;
      _liveOff = false;
    });
    // Live evidence: real connections carrying this domain prove where the
    // core actually sends it (covers the remote geosite/geoip steps too).
    if (state.vpn.phase == VpnPhase.connected) {
      final found = await _poller.findForDomain(domain);
      if (!mounted) return;
      setState(() {
        _live = found;
        _checking = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _live = const [];
        _liveOff = true;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ruleDetect)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            TextField(
              controller: _input,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _detect(),
              decoration: InputDecoration(
                labelText: l10n.ruleDetectInput,
                hintText: 'youtube.com',
                prefixIcon: const Icon(Icons.travel_explore_rounded),
                errorText: _inputError,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _checking ? null : _detect,
                  icon: _checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2.2))
                      : const Icon(Icons.travel_explore_rounded),
                  label: Text(l10n.detect),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.ruleDetectHint,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              _VerdictCard(result: _result!),
              const SizedBox(height: 12),
              for (var i = 0; i < _result!.steps.length; i++)
                _StepTile(
                  step: _result!.steps[i],
                  last: i == _result!.steps.length - 1,
                ),
              const SizedBox(height: 12),
              _LiveCard(
                live: _live,
                off: _liveOff,
                vpnOn: state.vpn.phase == VpnPhase.connected,
              ),
            ] else ...[
              const SizedBox(height: 24),
              Text(
                l10n.ruleDetectEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerdictCard extends StatelessWidget {
  final DetectResult result;

  const _VerdictCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    String title;
    IconData icon;
    Color bg;
    Color fg;
    switch (result.verdict) {
      case DetectKind.block:
        title = l10n.verdictBlock;
        icon = Icons.block_rounded;
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
        break;
      case DetectKind.direct:
        title = l10n.verdictDirect;
        icon = Icons.call_split_rounded;
        bg = scheme.tertiaryContainer;
        fg = scheme.onTertiaryContainer;
        break;
      case DetectKind.proxy:
        title = l10n.verdictProxy;
        icon = Icons.shield_rounded;
        bg = scheme.primaryContainer;
        fg = scheme.onPrimaryContainer;
        break;
      default:
        title = l10n.verdictUnknown;
        icon = Icons.help_outline_rounded;
        bg = scheme.surfaceContainerHigh;
        fg = scheme.onSurface;
    }
    return Card.filled(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${result.domain}${result.isIp ? ' · IP' : ''}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: fg.withValues(alpha: 0.8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    result.reason == 'final'
                        ? l10n.byFinal
                        : l10n.matchedRule(result.reason),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: fg.withValues(alpha: 0.85)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
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

class _StepTile extends StatelessWidget {
  final DetectStep step;
  final bool last;

  const _StepTile({required this.step, required this.last});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (step.kind) {
      DetectKind.proxy => (Icons.check_circle_rounded, scheme.primary),
      DetectKind.direct => (Icons.check_circle_rounded, scheme.tertiary),
      DetectKind.block => (Icons.block_rounded, scheme.error),
      DetectKind.unknown => (Icons.help_outline_rounded, scheme.onSurfaceVariant),
      DetectKind.skip => (Icons.remove_circle_outline_rounded,
          scheme.onSurfaceVariant.withValues(alpha: 0.55)),
    };
    final title = switch (step.code) {
      'ads' => l10n.stepAds,
      'split' => l10n.stepSplit,
      'custom' => l10n.stepCustom,
      'ru' => l10n.stepRu,
      _ => l10n.stepFinal,
    };
    final note = switch (step.code) {
      'ads' => l10n.stepAdsUnknown,
      'split' => l10n.stepSplitNote,
      'ru' => l10n.stepRuNote,
      _ => '',
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              const SizedBox(width: 2),
              Icon(icon, size: 18, color: color),
              if (!last)
                Expanded(
                  child: Container(width: 1.5, color: scheme.outlineVariant),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    note.isEmpty ? step.detail : '${step.detail} — $note',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  final List<LiveConnection>? live;
  final bool off;
  final bool vpnOn;

  const _LiveCard({required this.live, required this.off, required this.vpnOn});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final data = live;
    final text = data == null
        ? l10n.liveOffHint
        : off
            ? l10n.liveOff
            : data.isEmpty
                ? l10n.liveNone
                : l10n.liveFound(data.length);
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              off || !vpnOn ? Icons.wifi_off_rounded : Icons.wifi_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.liveCheck,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (data != null && data.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final c in data.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '${c.bestHost} · '
                          '${c.chains.isEmpty ? '—' : c.chains.reversed.join(' → ')}'
                          '${c.rule.isEmpty ? '' : ' · ${c.rule}'}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  fontFamily: 'monospace',
                                  color: scheme.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
