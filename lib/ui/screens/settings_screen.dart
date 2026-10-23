import 'package:flutter/material.dart';

import '../../core/config_builder.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            title: l10n.updates,
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
                      subtitle: Text('${s.count} ${l10n.entries}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () => state.updateSubscription(s),
                      ),
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
