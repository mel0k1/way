import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/parser.dart';
import '../core/profile.dart';
import '../core/stats.dart';
import '../core/subscriptions.dart';
import '../core/vpn_bridge.dart';

class SubEntry extends Subscription {
  SubEntry({
    required super.id,
    required super.name,
    required super.url,
    super.lastUpdate,
    super.count = 0,
  });
}

class AppState extends ChangeNotifier {
  final VpnBridge bridge = createBridge();
  final SubscriptionService subsService = SubscriptionService();
  final StatsPoller statsPoller = StatsPoller();

  List<Profile> profiles = [];
  List<Subscription> subs = [];
  String? selectedId;

  String engine = 'singbox';
  bool preferTun = true;
  String themeMode = 'system';
  String localeCode = '';
  bool autoUpdate = true;

  VpnStatus vpn = const VpnStatus();
  WayStats stats = WayStats.zero;
  List<String> logLines = [];
  String? singBoxLogPath;
  String? xrayLogPath;

  Timer? _statusTimer;
  Timer? _subsTimer;
  SharedPreferences? _prefs;

  Profile? get selected {
    if (profiles.isEmpty) return null;
    final idx = profiles.indexWhere((p) => p.id == selectedId);
    if (idx >= 0) return profiles[idx];
    return profiles.first;
  }

  bool get isDesktop =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  String get effectiveLocale {
    if (localeCode.isNotEmpty) return localeCode;
    final system = PlatformDispatcher.instance.locale.languageCode;
    return system == 'ru' ? 'ru' : 'en';
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;
    final settingsRaw = prefs.getString('way.settings');
    if (settingsRaw != null) {
      try {
        final s = json.decode(settingsRaw) as Map<String, dynamic>;
        engine = s['engine'] as String? ?? engine;
        preferTun = s['tun'] as bool? ?? preferTun;
        themeMode = s['theme'] as String? ?? themeMode;
        localeCode = s['locale'] as String? ?? localeCode;
        autoUpdate = s['autoupdate'] as bool? ?? autoUpdate;
        selectedId = s['selected'] as String?;
      } catch (_) {}
    }
    final profilesRaw = prefs.getString('way.profiles');
    if (profilesRaw != null) {
      try {
        final list = json.decode(profilesRaw) as List;
        profiles = list
            .map((e) => Profile.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    final subsRaw = prefs.getString('way.subs');
    if (subsRaw != null) {
      try {
        final list = json.decode(subsRaw) as List;
        subs = list
            .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    final docs = await getApplicationSupportDirectory();
    singBoxLogPath = '${docs.path}/waybox.log';
    xrayLogPath = '${docs.path}/wayxray.log';
    if (!preferTun && !isDesktop) preferTun = true;
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
    _subsTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (autoUpdate) updateSubscriptions();
    });
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString('way.settings', json.encode({
      'engine': engine,
      'tun': preferTun,
      'theme': themeMode,
      'locale': localeCode,
      'autoupdate': autoUpdate,
      'selected': selectedId,
    }));
    await prefs.setString(
      'way.profiles',
      json.encode(profiles.map((p) => p.toJson()).toList()),
    );
    await prefs.setString(
      'way.subs',
      json.encode(subs.map((s) => s.toJson()).toList()),
    );
  }

  void log(String line) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    logLines.add('[$stamp] $line');
    if (logLines.length > 500) {
      logLines.removeRange(0, logLines.length - 500);
    }
    notifyListeners();
  }

  void _tick() async {
    final s = await bridge.status();
    if (s.phase != vpn.phase || (s.error != null && s.error != vpn.error)) {
      if (vpn.phase == VpnPhase.connecting && s.phase == VpnPhase.connected) {
        log('connected');
      }
      if (vpn.phase != VpnPhase.stopped && s.phase == VpnPhase.stopped) {
        log('disconnected');
        stats = WayStats.zero;
      }
      vpn = s;
      notifyListeners();
    }
    if (vpn.phase == VpnPhase.connected) {
      stats = await statsPoller.fetch();
      notifyListeners();
    }
  }

  Future<void> connect() async {
    final profile = selected;
    if (profile == null) {
      vpn = const VpnStatus(error: 'no_profile');
      notifyListeners();
      return;
    }
    log('connecting via ${profile.name} ($engine)');
    vpn = const VpnStatus(phase: VpnPhase.connecting);
    notifyListeners();
    final tun = isDesktop ? preferTun : true;
    final result = await bridge.connect(ConnectRequest(
      engine: engine,
      tun: tun,
      profile: profile,
      logPath: engine == 'xray' ? (xrayLogPath ?? '/tmp/wayxray.log') : (singBoxLogPath ?? '/tmp/waybox.log'),
    ));
    if (result.error != null) {
      log('error: ${result.error}');
      vpn = VpnStatus(error: result.error);
      notifyListeners();
      return;
    }
    vpn = result;
    notifyListeners();
  }

  Future<void> disconnect() async {
    log('disconnecting');
    vpn = const VpnStatus(phase: VpnPhase.disconnecting);
    notifyListeners();
    await bridge.disconnect();
    stats = WayStats.zero;
    vpn = await bridge.status();
    notifyListeners();
  }

  void addFromLink(String link, {String subId = ''}) {
    final parsed = LinkParser.parseMany(link);
    for (final p in parsed) {
      p.subId = subId;
      profiles.add(p);
    }
    if (selectedId == null && profiles.isNotEmpty) selectedId = profiles.first.id;
    log('added ${parsed.length} profile(s)');
    _persist();
    notifyListeners();
  }

  void addSubscription(String url, String name) {
    final sub = Subscription(
      id: 'sub${DateTime.now().millisecondsSinceEpoch}',
      name: name.isEmpty ? 'Subscription' : name,
      url: url,
    );
    subs.add(sub);
    updateSubscription(sub);
  }

  Future<void> updateSubscription(Subscription sub) async {
    try {
      final fetched = await subsService.fetch(sub);
      profiles.removeWhere((p) => p.subId == sub.id);
      profiles.addAll(fetched);
      sub.lastUpdate = DateTime.now();
      sub.count = fetched.length;
      if (selectedId == null && profiles.isNotEmpty) {
        selectedId = profiles.first.id;
        await _persist();
      } else {
        await _persist();
      }
      log('subscription "${sub.name}": ${fetched.length} profiles');
      notifyListeners();
    } catch (e) {
      log('subscription "${sub.name}" failed: $e');
      notifyListeners();
    }
  }

  Future<void> updateSubscriptions() async {
    for (final sub in List<Subscription>.from(subs)) {
      await updateSubscription(sub);
    }
  }

  void removeSubscription(String id) {
    subs.removeWhere((s) => s.id == id);
    profiles.removeWhere((p) => p.subId == id);
    _persist();
    notifyListeners();
  }

  void select(String id) {
    selectedId = id;
    _persist();
    notifyListeners();
  }

  void removeProfile(String id) {
    profiles.removeWhere((p) => p.id == id);
    if (selectedId == id) selectedId = profiles.isNotEmpty ? profiles.first.id : null;
    _persist();
    notifyListeners();
  }

  void setEngine(String value) {
    engine = value;
    _persist();
    notifyListeners();
  }

  void setPreferTun(bool value) {
    preferTun = value;
    _persist();
    notifyListeners();
  }

  void setThemeMode(String value) {
    themeMode = value;
    _persist();
    notifyListeners();
  }

  void setLocale(String value) {
    localeCode = value;
    _persist();
    notifyListeners();
  }

  void setAutoUpdate(bool value) {
    autoUpdate = value;
    _persist();
    notifyListeners();
  }

  void clearLogs() {
    logLines.clear();
    try {
      File(singBoxLogPath ?? '').deleteSync();
    } catch (_) {}
    try {
      File(xrayLogPath ?? '').deleteSync();
    } catch (_) {}
    notifyListeners();
  }

  List<String> coreLogTail({int lines = 300}) {
    final path = engine == 'xray' ? xrayLogPath : singBoxLogPath;
    if (path == null) return const [];
    try {
      final file = File(path);
      if (!file.existsSync()) return const [];
      final content = file.readAsStringSync();
      final all = content.split('\n');
      return all.length <= lines ? all : all.sublist(all.length - lines);
    } catch (_) {
      return const [];
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _subsTimer?.cancel();
    statsPoller.dispose();
    super.dispose();
  }
}
