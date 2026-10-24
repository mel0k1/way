import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config_builder.dart';
import '../../core/subscriptions.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import 'package:provider/provider.dart';
import 'split_apps_screen.dart';

class _SplitProcessesField extends StatefulWidget {
  final AppState state;

  const _SplitProcessesField(this.state);

  @override
  State<_SplitProcessesField> createState() => _SplitProcessesFieldState();
}

class _SplitProcessesFieldState extends State<_SplitProcessesField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.splitApps.join(', '));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String value) {
    widget.state.setSplitApps(value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    return TextField(
      maxLines: 3,
      controller: _controller,
      decoration: InputDecoration(
        labelText: l10n.splitProcesses,
        hintText: 'chrome.exe, firefox.exe',
        border: const OutlineInputBorder(),
      ),
      onSubmitted: _commit,
      onChanged: _commit,
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String _subLine(Subscription s, L10n l10n) {
    final base = '${s.count} ${l10n.entries}';
    final hasQuota = s.usedBytes > 0 || s.totalBytes > 0;
    final hasExpire = s.expiresAt != null;
    if (!hasQuota && !hasExpire) return base;
    final parts = <String>[base];
    if (hasQuota) {
      final used = _fmtBytes(s.usedBytes);
      final total = s.totalBytes > 0 ? _fmtBytes(s.totalBytes) : l10n.unlimited;
      parts.add('$used / $total');
    }
    if (hasExpire) {
      final d = s.expiresAt!.toLocal();
      parts.add('${l10n.expiresLabel} '
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}');
    }
    return parts.join(' · ');
  }

  String _fmtBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value >= 100 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 12),
            child: Text(
              l10n.settingsTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          _SectionCard(
            title: l10n.engine,
            hint: l10n.engineHint,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'singbox', label: Text('sing-box'), icon: Icon(Icons.view_in_ar_rounded)),
                ButtonSegment(value: 'xray', label: Text('xray'), icon: Icon(Icons.bolt_rounded)),
              ],
              selected: {state.engine},
              onSelectionChanged: (s) => state.setEngine(s.first),
            ),
          ),
          if (state.isDesktop)
            _SectionCard(
              title: l10n.mode,
              hint: l10n.tunHint,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(l10n.modeTun)),
                  ButtonSegment(value: false, label: Text(l10n.modeProxy)),
                ],
                selected: {state.preferTun},
                onSelectionChanged: (s) => state.setPreferTun(s.first),
              ),
            ),
          _SectionCard(
            title: l10n.routing,
            hint: l10n.routingHint,
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'global', label: Text(l10n.routingGlobal)),
                    ButtonSegment(
                        value: 'ru', label: Text(l10n.routingRu)),
                  ],
                  selected: {state.routingMode},
                  onSelectionChanged: (s) => state.setRoutingMode(s.first),
                ),
                SwitchListTile(
                  title: Text(l10n.blockAds),
                  subtitle: Text(l10n.blockAdsHint),
                  value: state.blockAds,
                  onChanged: state.setBlockAds,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          _SectionCard(
            title: l10n.security,
            child: Column(
              children: [
                if (!state.isDesktop)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.policy_rounded),
                    title: Text(l10n.alwaysOn),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () async {
                      try {
                        await const MethodChannel('way/core')
                            .invokeMethod('vpn_settings');
                      } on PlatformException {
                        debugPrint('vpn settings unavailable');
                      }
                    },
                  ),
                SwitchListTile(
                  title: Text(l10n.killSwitch),
                  subtitle: Text(state.isDesktop
                      ? l10n.killSwitchHintDesktop
                      : l10n.killSwitchHintAndroid),
                  value: state.killSwitch,
                  onChanged: state.isDesktop ? state.setKillSwitch : null,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          if (state.engine == 'singbox')
            _SectionCard(
              title: l10n.splitTunnel,
              hint: state.isDesktop ? l10n.splitHintWindows : l10n.splitHintAndroid,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'off', label: Text(l10n.splitOff)),
                      ButtonSegment(
                          value: 'include', label: Text(l10n.splitInclude)),
                      ButtonSegment(
                          value: 'exclude', label: Text(l10n.splitExclude)),
                    ],
                    selected: {state.splitMode},
                    onSelectionChanged: (s) => state.setSplitMode(s.first),
                  ),
                  if (state.splitMode != 'off') ...[
                    const SizedBox(height: 12),
                    if (state.isDesktop)
                      _SplitProcessesField(state)
                    else
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.apps_rounded),
                        title: Text(l10n.splitPickApps),
                        subtitle: Text(
                            '${state.splitApps.length} ${l10n.splitSelected}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SplitAppsScreen()),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          _SectionCard(
            title: l10n.updates,
            hint: l10n.subUaHint,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.autoUpdate),
                  value: state.autoUpdate,
                  onChanged: state.setAutoUpdate,
                  contentPadding: EdgeInsets.zero,
                ),
                if (state.subs.isNotEmpty)
                  ...state.subs.map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.rss_feed_rounded),
                      title: Text(s.name, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_subLine(s, l10n)),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () => state.updateSubscription(s),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: state.subUserAgent,
                  onFieldSubmitted: state.setSubUserAgent,
                  decoration: InputDecoration(
                    labelText: l10n.subUserAgent,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          _SectionCard(
            title: l10n.appearance,
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'system', label: Text(l10n.themeSystem)),
                    ButtonSegment(value: 'light', label: Text(l10n.themeLight)),
                    ButtonSegment(value: 'dark', label: Text(l10n.themeDark)),
                  ],
                  selected: {state.themeMode},
                  onSelectionChanged: (s) => state.setThemeMode(s.first),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: '', label: Text(l10n.langSystem)),
                    const ButtonSegment(value: 'ru', label: Text('RU')),
                    const ButtonSegment(value: 'en', label: Text('EN')),
                  ],
                  selected: {state.localeCode},
                  onSelectionChanged: (s) => state.setLocale(s.first),
                ),
              ],
            ),
          ),
          _SectionCard(
            title: l10n.about,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/icon/way.png',
                        width: 44,
                        height: 44,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Way',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            '${l10n.version}: 1.0.0 · ${l10n.license}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${l10n.cores}: sing-box 1.14.3 · xray-core v26.10.21',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Control API: 127.0.0.1:${WayPorts.controlApi}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? hint;
  final Widget child;

  const _SectionCard({required this.title, this.hint, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            child,
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
