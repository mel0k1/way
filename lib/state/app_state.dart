import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/latency.dart';
import '../core/parser.dart';
import '../core/profile.dart';
import '../core/stats.dart';
import '../core/subscriptions.dart';
import '../core/toast.dart';
import '../core/updates.dart';
import '../core/version.dart';
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
  static const autoId = '__auto__';

  final VpnBridge bridge = createBridge();
  final SubscriptionService subsService = SubscriptionService();
  final StatsPoller statsPoller = StatsPoller();
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  List<Profile> profiles = [];
  List<Subscription> subs = [];
  String? selectedId;

  String engine = 'singbox';
  bool preferTun = true;
  String themeMode = 'system';
  String localeCode = '';
  bool autoUpdate = true;
  String routingMode = 'global';
  bool blockAds = false;
  bool killSwitch = false;
  String splitMode = 'off';
  List<String> splitApps = [];
  String subUserAgent = 'v2rayTun/1.7.6';
  bool autoSelect = false;
  bool autoStart = false;
  bool connectOnLaunch = false;
  bool desktopNotify = true;
  bool autoCheckUpdates = true;
  String? hwid;
  Map<String, int?> latencies = {};
  bool latencyTesting = false;
  UpdateInfo? pendingUpdate;
  bool checkingUpdate = false;

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

  List<Profile> get engineProfiles =>
      profiles.where((p) => p.supportedOn(engine)).toList();

  Profile? get bestProfile {
    final rated = engineProfiles
        .where((p) => latencies[p.id] != null)
        .toList()
      ..sort((a, b) => latencies[a.id]!.compareTo(latencies[b.id]!));
    return rated.isEmpty ? null : rated.first;
  }

  Profile? get effectiveProfile {
    if (autoSelect) {
      final best = bestProfile;
      if (best != null) return best;
    }
    return selected;
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
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    await _loadSecure(prefs);
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
        routingMode = s['routing'] as String? ?? routingMode;
        blockAds = s['blockads'] as bool? ?? blockAds;
        killSwitch = s['killswitch'] as bool? ?? killSwitch;
        splitMode = s['splitmode'] as String? ?? splitMode;
        splitApps = (s['splitapps'] as List?)?.cast<String>() ?? splitApps;
        subUserAgent = s['subua'] as String? ?? subUserAgent;
        autoSelect = s['autoselect'] as bool? ?? autoSelect;
        autoStart = s['autostart'] as bool? ?? autoStart;
        connectOnLaunch = s['connectlaunch'] as bool? ?? connectOnLaunch;
        desktopNotify = s['desktopnotify'] as bool? ?? desktopNotify;
        autoCheckUpdates = s['checkupdates'] as bool? ?? autoCheckUpdates;
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
    if (autoStart || !isDesktop) {
      await bridge.setAutostart(autoStart);
    }
    Timer(const Duration(seconds: 3), _autoConnectOnLaunch);
    if (autoCheckUpdates) {
      Timer(const Duration(seconds: 4), () => checkForUpdates());
    }
    notifyListeners();
  }

  Future<void> _autoConnectOnLaunch() async {
    if (!connectOnLaunch) return;
    try {
      final s = await bridge.status();
      if (s.phase != VpnPhase.stopped || s.error != null) return;
      log('auto-connect on launch');
      await connect();
    } catch (_) {
      return;
    }
  }

  bool get _ru => effectiveLocale == 'ru';

  Future<void> _loadSecure(SharedPreferences prefs) async {
    try {
      final migratedProfiles = prefs.getString('way.profiles');
      final migratedSubs = prefs.getString('way.subs');
      if (migratedProfiles != null) {
        if (await _secure.containsKey(key: 'way.profiles') != true) {
          await _secure.write(key: 'way.profiles', value: migratedProfiles);
        }
        await prefs.remove('way.profiles');
      }
      if (migratedSubs != null) {
        if (await _secure.containsKey(key: 'way.subs') != true) {
          await _secure.write(key: 'way.subs', value: migratedSubs);
        }
        await prefs.remove('way.subs');
      }
      final profilesRaw = await _secure.read(key: 'way.profiles');
      if (profilesRaw != null && profilesRaw.isNotEmpty) {
        try {
          final list = json.decode(profilesRaw) as List;
          profiles = list
              .map((e) => Profile.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }
      final subsRaw = await _secure.read(key: 'way.subs');
      if (subsRaw != null && subsRaw.isNotEmpty) {
        try {
          final list = json.decode(subsRaw) as List;
          subs = list
              .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }
      hwid = await _secure.read(key: 'way.hwid');
      if (hwid == null || hwid!.isEmpty) {
        hwid = _genUuidV4();
        await _secure.write(key: 'way.hwid', value: hwid!);
      }
    } catch (e) {
      debugPrint('secure storage load failed: $e');
      if (hwid == null || hwid!.isEmpty) hwid = _genUuidV4();
    }
  }

  String _genUuidV4() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
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
      'routing': routingMode,
      'blockads': blockAds,
      'killswitch': killSwitch,
      'splitmode': splitMode,
      'splitapps': splitApps,
      'subua': subUserAgent,
      'autoselect': autoSelect,
      'autostart': autoStart,
      'connectlaunch': connectOnLaunch,
      'desktopnotify': desktopNotify,
      'checkupdates': autoCheckUpdates,
    }));
    try {
      await _secure.write(
        key: 'way.profiles',
        value: json.encode(profiles.map((p) => p.toJson()).toList()),
      );
      await _secure.write(
        key: 'way.subs',
        value: json.encode(subs.map((s) => s.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('secure storage persist failed: $e');
    }
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
    var profile = selected;
    if (autoSelect) {
      final best = bestProfile;
      if (best != null) profile = best;
    }
    if (profile == null) {
      vpn = const VpnStatus(error: 'no_profile');
      notifyListeners();
      return;
    }
    if (!profile.supportedOn(engine)) {
      final alt = engine == 'singbox' ? 'xray' : 'singbox';
      if (profile.supportedOn(alt)) {
        log('profile "${profile.name}" needs $alt, switching engine');
        engine = alt;
      } else {
        log('profile "${profile.name}" is not supported by any engine');
        vpn = VpnStatus(error: 'unsupported_profile');
        notifyListeners();
        return;
      }
    }
    final group = autoSelect && engine == 'singbox' && engineProfiles.length > 1
        ? engineProfiles
        : const <Profile>[];
    log('connecting via ${profile.name} ($engine)');
    vpn = const VpnStatus(phase: VpnPhase.connecting);
    notifyListeners();
    final tun = isDesktop ? (preferTun || killSwitch) : true;
    final result = await bridge.connect(ConnectRequest(
      engine: engine,
      tun: tun,
      profile: profile,
      group: group,
      logPath: engine == 'xray' ? (xrayLogPath ?? '/tmp/wayxray.log') : (singBoxLogPath ?? '/tmp/waybox.log'),
      killSwitch: killSwitch && isDesktop,
      routingMode: routingMode,
      blockAds: blockAds,
      splitMode: splitMode,
      splitApps: List.unmodifiable(splitApps),
    ));
    if (result.error != null) {
      log('error: ${result.error}');
      vpn = VpnStatus(error: result.error);
      notifyListeners();
      return;
    }
    vpn = result;
    notifyListeners();
    final connectedName = profile.name;
    Timer(const Duration(seconds: 4), () async {
      if (!desktopNotify) return;
      final s = await bridge.status();
      if (s.phase == VpnPhase.connected) {
        showDesktopToast('Way', _ru ? 'Подключено · $connectedName' : 'Connected · $connectedName');
      }
    });
  }

  Future<void> disconnect() async {
    log('disconnecting');
    vpn = const VpnStatus(phase: VpnPhase.disconnecting);
    notifyListeners();
    await bridge.disconnect();
    stats = WayStats.zero;
    vpn = await bridge.status();
    notifyListeners();
    if (desktopNotify) {
      showDesktopToast('Way', _ru ? 'Отключено' : 'Disconnected');
    }
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
      final fetched = await subsService.fetch(
        sub,
        userAgent: subUserAgent,
        hwid: hwid,
      );
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
    autoSelect = false;
    _persist();
    notifyListeners();
  }

  void setAutoSelect(bool value) {
    autoSelect = value;
    _persist();
    notifyListeners();
    if (value) testLatencies();
  }

  Future<void> testLatencies() async {
    if (latencyTesting) return;
    final targets = engineProfiles;
    if (targets.isEmpty) return;
    latencyTesting = true;
    notifyListeners();
    final results = await LatencyTester.testAll(targets);
    latencies.addAll(results);
    latencyTesting = false;
    log('latency: ${targets.length} server(s) tested');
    notifyListeners();
  }

  void setSubUserAgent(String value) {
    subUserAgent = value.trim().isEmpty ? 'v2rayTun/1.7.6' : value.trim();
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

  void setRoutingMode(String value) {
    routingMode = value;
    _persist();
    notifyListeners();
  }

  void setBlockAds(bool value) {
    blockAds = value;
    _persist();
    notifyListeners();
  }

  void setKillSwitch(bool value) {
    killSwitch = value;
    _persist();
    notifyListeners();
  }

  void setSplitMode(String value) {
    splitMode = value;
    _persist();
    notifyListeners();
  }

  void setSplitApps(List<String> apps) {
    splitApps = apps;
    _persist();
    notifyListeners();
  }

  Future<void> setAutoStart(bool value) async {
    autoStart = value;
    notifyListeners();
    try {
      await bridge.setAutostart(value);
    } catch (_) {
      return;
    }
    _persist();
    notifyListeners();
  }

  void setConnectOnLaunch(bool value) {
    connectOnLaunch = value;
    _persist();
    notifyListeners();
  }

  void setDesktopNotify(bool value) {
    desktopNotify = value;
    _persist();
    notifyListeners();
  }

  void setAutoCheckUpdates(bool value) {
    autoCheckUpdates = value;
    _persist();
    notifyListeners();
  }

  Future<UpdateInfo?> checkForUpdates() async {
    if (checkingUpdate) return pendingUpdate;
    checkingUpdate = true;
    notifyListeners();
    final info = await UpdateChecker.fetchLatest();
    checkingUpdate = false;
    UpdateInfo? found;
    if (info != null && UpdateChecker.isNewer(info.version, appVersion)) {
      found = info;
    }
    pendingUpdate = found;
    if (info == null) {
      log('update check failed');
    } else {
      log(found != null
          ? 'update available: v${found.version}'
          : 'up to date (v$appVersion)');
    }
    notifyListeners();
    return found;
  }

  void clearPendingUpdate() {
    pendingUpdate = null;
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
