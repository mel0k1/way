import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config_builder.dart';
import '../../core/subscriptions.dart';
import '../../core/version.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import 'package:provider/provider.dart';
import '../widgets/update_dialog.dart';
import 'connections_screen.dart';
import 'route_rules_screen.dart';
import 'rule_detect_screen.dart';
import 'split_apps_screen.dart';
import 'uwp_loopback_screen.dart';

/// Windows detection that survives every platform (dart:io throws nowhere
/// here, but the try keeps the getter total).
bool get _isWindows {
  try {
    return Platform.isWindows;
  } catch (_) {
    return false;
  }
}

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

  Future<bool?> _onImportBackup(BuildContext context, AppState state) async {
    final l10n = L10nScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importBackup),
        content: Text(l10n.backupImportConfirm),
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
    if (confirmed != true) return null;
    return state.importBackup();
  }

  Future<void> _onCheckUpdates(BuildContext context, AppState state) async {
    final l10n = L10nScope.of(context);
    final found = await state.checkForUpdates();
    if (!context.mounted) return;
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.upToDate)),
      );
      return;
    }
    await showUpdateDialog(context, found);
    if (context.mounted) state.clearPendingUpdate();
  }

  Future<void> _onBattery(BuildContext context, AppState state) async {
    final l10n = L10nScope.of(context);
    if (state.batteryIgnored == true) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.batteryDialogTitle),
        content: Text(l10n.batteryDialogText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.batteryAsk),
          ),
        ],
      ),
    );
    if (confirmed == true) await state.requestBatteryIgnore();
  }

  Future<void> _pickUpdateInterval(BuildContext context, AppState state) async {
    final options = [15, 30, 60, 120, 360, 1440];
    final l10n = L10nScope.of(context);
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.updateInterval),
        children: [
          for (final m in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, m),
              child: Text(
                l10n.intervalValue(m),
                style: TextStyle(
                  color: m == state.autoUpdateMin
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  fontWeight: m == state.autoUpdateMin
                      ? FontWeight.w600
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
    if (picked != null) state.setUpdateInterval(picked);
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
          _SectionCard(
            title: l10n.mode,
            hint: state.isDesktop ? l10n.tunHint : l10n.tunHintAndroid,
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.rule_rounded),
                  title: Text(l10n.rulesEditor),
                  subtitle: Text(
                    state.customRules.isEmpty
                        ? l10n.rulesHint
                        : '${state.customRules.length} ${l10n.rulesCount}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const RouteRulesScreen()),
                  ),
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
                if (state.isDesktop && _isWindows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.store_rounded),
                    title: Text(l10n.uwpLoopback),
                    subtitle: Text(l10n.uwpEntrySub),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const UwpLoopbackScreen()),
                    ),
                  ),
                if (!state.isDesktop)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      state.batteryIgnored == true
                          ? Icons.battery_saver_rounded
                          : Icons.battery_alert_rounded,
                      color: state.batteryIgnored == true ? scheme.primary : scheme.error,
                    ),
                    title: Text(l10n.batteryTitle),
                    subtitle: Text(state.batteryIgnored == true
                        ? l10n.batteryAllowed
                        : l10n.batteryHint),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _onBattery(context, state),
                  ),
              ],
            ),
          ),
          _SectionCard(
            title: l10n.dnsSection,
            hint: l10n.dnsServerHint,
            child: Column(
              children: [
                TextFormField(
                  initialValue: state.dnsHost,
                  onFieldSubmitted: state.setDnsHost,
                  decoration: InputDecoration(
                    labelText: l10n.dnsServer,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: state.dnsStrategy,
                  decoration: InputDecoration(
                    labelText: l10n.dnsStrategy,
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: 'prefer_ipv4', child: Text(l10n.dnsPreferV4)),
                    DropdownMenuItem(value: 'prefer_ipv6', child: Text(l10n.dnsPreferV6)),
                    DropdownMenuItem(value: 'ipv4_only', child: Text(l10n.dnsOnlyV4)),
                    DropdownMenuItem(value: 'ipv6_only', child: Text(l10n.dnsOnlyV6)),
                  ],
                  onChanged: (v) {
                    if (v != null) state.setDnsStrategy(v);
                  },
                ),
              ],
            ),
          ),
          _SectionCard(
            title: l10n.advanced,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.tlsFragment),
                  subtitle: Text(l10n.tlsFragmentHint),
                  value: state.tlsFragment,
                  onChanged: state.setTlsFragment,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: state.muxProtocol,
                  decoration: InputDecoration(
                    labelText: l10n.mux,
                    helperText: l10n.muxHint,
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: '', child: Text(l10n.muxOff)),
                    const DropdownMenuItem(value: 'h2mux', child: Text('h2mux')),
                    const DropdownMenuItem(value: 'smux', child: Text('smux')),
                    const DropdownMenuItem(value: 'yamux', child: Text('yamux')),
                  ],
                  onChanged: (v) {
                    if (v != null) state.setMux(v);
                  },
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
                if (state.autoUpdate)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.update_rounded),
                    title: Text(l10n.updateInterval),
                    trailing: Text(
                      l10n.intervalValue(state.autoUpdateMin),
                      style: TextStyle(color: scheme.primary),
                    ),
                    onTap: () => _pickUpdateInterval(context, state),
                  ),
                if (state.subs.isNotEmpty)
                  ...state.subs.map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.rss_feed_rounded),
                      title: Text(s.name, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_subLine(s, l10n)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            tooltip: l10n.updateNow,
                            onPressed: () => state.updateSubscription(s),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            tooltip: l10n.delete,
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(l10n.delete),
                                  content: Text(l10n.deleteSubConfirm),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(l10n.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(l10n.delete),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) state.removeSubscription(s.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: state.subUserAgent,
                  onFieldSubmitted: state.setSubUserAgent,
                  decoration: InputDecoration(
                    labelText: l10n.subUserAgent,
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
                if (!state.isDesktop) ...[
                  SwitchListTile(
                    title: Text(l10n.materialYou),
                    subtitle: Text(l10n.materialYouHint),
                    value: state.dynamicColors,
                    onChanged: state.setDynamicColors,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
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
            title: l10n.appSection,
            hint: l10n.checkUpdatesHint,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.autostart),
                  subtitle: Text(state.isDesktop
                      ? l10n.autostartHintDesktop
                      : l10n.autostartHintAndroid),
                  value: state.autoStart,
                  onChanged: (v) => state.setAutoStart(v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: Text(l10n.connectOnLaunch),
                  subtitle: Text(l10n.connectOnLaunchHint),
                  value: state.connectOnLaunch,
                  onChanged: state.setConnectOnLaunch,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: Text(l10n.autoReconnect),
                  subtitle: Text(l10n.autoReconnectHint),
                  value: state.autoReconnect,
                  onChanged: state.setAutoReconnect,
                  contentPadding: EdgeInsets.zero,
                ),
                if (state.isDesktop)
                  SwitchListTile(
                    title: Text(l10n.desktopNotifications),
                    subtitle: Text(l10n.desktopNotificationsHint),
                    value: state.desktopNotify,
                    onChanged: state.setDesktopNotify,
                    contentPadding: EdgeInsets.zero,
                  ),
                if (state.isDesktop)
                  SwitchListTile(
                    title: Text(l10n.closeToTray),
                    subtitle: Text(l10n.closeToTrayHint),
                    value: state.closeToTray,
                    onChanged: state.setCloseToTray,
                    contentPadding: EdgeInsets.zero,
                  ),
                SwitchListTile(
                  title: Text(l10n.autoCheckUpdates),
                  value: state.autoCheckUpdates,
                  onChanged: state.setAutoCheckUpdates,
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: state.checkingUpdate
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt_rounded),
                  title: Text(l10n.checkUpdates),
                  subtitle: state.pendingUpdate != null
                      ? Text(
                          '${l10n.updateAvailable}: v${state.pendingUpdate!.version}',
                          style: TextStyle(color: scheme.primary),
                        )
                      : Text('${l10n.currentVersion}: $appVersion'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _onCheckUpdates(context, state),
                ),
              ],
            ),
          ),
          _SectionCard(
            title: l10n.monitoring,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: Text(l10n.connectionsTitle),
                  subtitle: Text(l10n.connectionsSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ConnectionsScreen()),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.travel_explore_outlined),
                  title: Text(l10n.ruleDetect),
                  subtitle: Text(l10n.ruleDetectSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const RuleDetectScreen()),
                  ),
                ),
              ],
            ),
          ),
          _SectionCard(
            title: l10n.localApi,
            hint: l10n.localApiHint,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.localApi),
                  subtitle: Text(
                    state.localApiServer.running
                        ? '${l10n.apiRunning} · http://127.0.0.1:${state.localApiPort}'
                        : l10n.apiStopped,
                  ),
                  value: state.localApi,
                  onChanged: (v) => state.setLocalApi(v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (state.localApi && state.apiToken?.isNotEmpty == true)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.key_rounded),
                    title: Text(l10n.apiToken),
                    subtitle: Text(
                      state.apiToken ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      tooltip: l10n.copy,
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: state.apiToken ?? ''),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(l10n.copied),
                            behavior: SnackBarBehavior.floating,
                            width: 320,
                          ));
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          _SectionCard(
            title: l10n.dataSection,
            hint: l10n.backupHint,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.ios_share_rounded),
                  title: Text(l10n.exportBackup),
                  onTap: () async {
                    final ok = await state.exportBackup();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? l10n.backupSaved : l10n.backupFailed),
                      behavior: SnackBarBehavior.floating,
                      width: 320,
                    ));
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.file_open_rounded),
                  title: Text(l10n.importBackup),
                  onTap: () async {
                    final ok = await _onImportBackup(context, state);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          ok == true ? l10n.backupImported : l10n.backupInvalid),
                      behavior: SnackBarBehavior.floating,
                      width: 320,
                    ));
                  },
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
                            '${l10n.version}: $appVersion · ${l10n.license}',
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
            if (hint != null) ...[
              const SizedBox(height: 10),
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
