import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/latency.dart';
import '../core/backup.dart';
import '../core/config_builder.dart';
import '../core/formats.dart';
import '../core/local_api.dart';
import '../core/parser.dart';
import '../core/profile.dart';
import '../core/reconnect_policy.dart';
import '../core/speedtest.dart';
import '../core/stats.dart';
import '../core/subscriptions.dart';
import '../core/toast.dart';
import '../core/tray.dart';
import '../core/updates.dart';
import '../core/version.dart';
import '../core/vpn_bridge.dart';
import '../core/warp.dart';
import '../l10n.dart';

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
  final TrayController tray = TrayController();
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  List<Profile> profiles = [];
  List<Subscription> subs = [];
  String? selectedId;

  String engine = 'singbox';
  bool preferTun = true;
  String themeMode = 'system';
  bool dynamicColors = true;
  String localeCode = '';
  bool autoUpdate = true;
  int autoUpdateMin = 60;
  String dnsHost = '1.1.1.1';
  String dnsStrategy = 'prefer_ipv4';
  bool tlsFragment = false;
  String muxProtocol = '';
  String routingMode = 'global';
  bool blockAds = false;
  bool killSwitch = false;
  String splitMode = 'off';
  List<String> splitApps = [];
  String subUserAgent = 'v2rayTun/1.7.6';
  bool autoSelect = false;
  bool autoStart = false;
  bool connectOnLaunch = false;
  bool autoReconnect = true;
  bool desktopNotify = true;
  bool autoCheckUpdates = true;
  bool closeToTray = true;
  bool onboardingDone = true;
  List<RouteRule> customRules = [];
  // Server list controls (search / sort) shared with the servers screen.
  String serverQuery = '';
  String serverSort = 'default'; // default | latency | name
  // Speed test of the current route.
  bool speedTesting = false;
  double? speedtestMbps;
  // Clipboard sniffer suggestion ("found vless:// — import?").
  String? pendingClipboard;
  // Loopback HTTP API for external control.
  bool localApi = false;
  int localApiPort = 20718;
  String? apiToken;
  String? hwid;
  Map<String, int?> latencies = {};
  bool latencyTesting = false;
  UpdateInfo? pendingUpdate;
  bool checkingUpdate = false;
  int pendingTab = -1;
  int lastImportCount = 0;
  bool lastImportWasSub = false;
  bool? batteryIgnored;
  bool pendingBatteryAsk = false;
  String? connIp;
  String? connCountry;
  static String? launchLink;

  VpnStatus vpn = const VpnStatus();
  WayStats stats = WayStats.zero;
  List<String> logLines = [];
  String? singBoxLogPath;
  String? xrayLogPath;

  Timer? _statusTimer;
  Timer? _subsTimer;
  Timer? _statsTimer;
  Timer? _clipboardTimer;
  bool _ipFetching = false;
  final Set<String> _updatingSubs = {};
  final Set<String> _dismissedClipboard = {};
  late final LocalApiServer localApiServer = LocalApiServer(
    status: () async => {
      'ok': true,
      'phase': vpn.phase.name,
      'error': vpn.error,
      'profile': selected?.name,
      'stats': {
        'up_bps': stats.upSpeed,
        'down_bps': stats.downSpeed,
        'total_up': stats.totalUp,
        'total_down': stats.totalDown,
        'connections': stats.connections,
      },
      'ip': connIp,
      'country': connCountry,
    },
    servers: () async => [
      for (final p in profiles)
        {
          'id': p.id,
          'name': p.name,
          'protocol': p.protocol,
          'server': p.server,
          'port': p.port,
          'latency': latencies[p.id],
          'favorite': p.favorite,
        },
    ],
    select: (id) async => select(id),
    connect: () => connect(),
    disconnect: () => disconnect(),
  );
  SharedPreferences? _prefs;

  // --- auto-reconnect watchdog state ---
  /// True while the user wants the VPN up (set by connect(), cleared by
  /// disconnect() or a fatal error). Drives automatic reconnection.
  bool _userWantsConnected = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  DateTime? _connectingSince;

  static const _wrapperSchemes = {
    'clash', 'clashmeta', 'sing-box', 'singbox', 'v2rayng', 'v2rayn',
    'sn', 'hiddify',
  };

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

  /// True while the watchdog holds a pending reconnect for a dropped session
  /// (the UI shows a "reconnecting · attempt N" hint).
  bool get isReconnecting =>
      _userWantsConnected &&
      vpn.phase == VpnPhase.stopped &&
      _reconnectTimer != null;

  /// Current watchdog attempt number (1-based) when [isReconnecting].
  int get reconnectAttempt => _reconnectAttempt;

  String get effectiveLocale {
    if (localeCode.isNotEmpty) return localeCode;
    final system = PlatformDispatcher.instance.locale.languageCode;
    return system == 'ru' ? 'ru' : 'en';
  }

  Future<void> init() async {
    try {
      await _initInner();
    } catch (_) {}
    if (launchLink != null) {
      final link = launchLink;
      launchLink = null;
      if (link != null) handleDeepLink(link);
    }
    bridge.setDeepLinkHandler(handleDeepLink);
    try {
      final pending = await bridge.takePendingLink();
      if (pending != null) handleDeepLink(pending);
    } catch (_) {}
    if (TrayController.supported) {
      unawaited(tray.init(
        onOpen: showWindow,
        onConnect: connect,
        onDisconnect: disconnect,
        onQuit: _quitFromTray,
      ));
      unawaited(tray.setCloseToTray(closeToTray));
    }
  }

  void showWindow() {
    unawaited(tray.showWindow());
  }

  Future<void> _quitFromTray() async {
    log('quit from tray');
    await tray.quit();
  }

  Future<void> _initInner() async {
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
        dynamicColors = s['dyn'] as bool? ?? dynamicColors;
        localeCode = s['locale'] as String? ?? localeCode;
        autoUpdate = s['autoupdate'] as bool? ?? autoUpdate;
        autoUpdateMin = (s['updatemin'] as num?)?.toInt() ?? autoUpdateMin;
        dnsHost = s['dnshost'] as String? ?? dnsHost;
        dnsStrategy = s['dnsstrategy'] as String? ?? dnsStrategy;
        tlsFragment = s['tlsfragment'] as bool? ?? tlsFragment;
        muxProtocol = s['mux'] as String? ?? muxProtocol;
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
        autoReconnect = s['autoreconnect'] as bool? ?? autoReconnect;
        desktopNotify = s['desktopnotify'] as bool? ?? desktopNotify;
        autoCheckUpdates = s['checkupdates'] as bool? ?? autoCheckUpdates;
        closeToTray = s['closetray'] as bool? ?? closeToTray;
        localApi = s['localapi'] as bool? ?? localApi;
        localApiPort = (s['localapiport'] as num?)?.toInt() ?? localApiPort;
        customRules = (s['rules'] as List?)
                ?.map((e) => RouteRule.fromJson(e as Map<String, dynamic>))
                .toList() ??
            customRules;
      } catch (_) {}
    }
    onboardingDone = prefs.getBool('way.intro_done') ?? false;
    final docs = await getApplicationSupportDirectory();
    singBoxLogPath = '${docs.path}/waybox.log';
    xrayLogPath = '${docs.path}/wayxray.log';
    try {
      apiToken = await _secure.read(key: 'way.apitoken');
    } catch (_) {}
    if (localApi) {
      unawaited(startLocalApi());
    }
    // Desktop-only clipboard sniffing loop — Android reads the clipboard on
    // app resume instead (background reads are restricted since Android 10).
    if (isDesktop) {
      _clipboardTimer = Timer.periodic(const Duration(seconds: 9), (_) {
        unawaited(sniffClipboard());
      });
    }
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
    _subsTimer = Timer.periodic(const Duration(minutes: 5), (_) => _checkSubUpdates());
    if (autoStart || !isDesktop) {
      try {
        final native = await bridge.autostartEnabled();
        if (native != autoStart) {
          await bridge.setAutostart(autoStart);
        }
      } catch (_) {}
    }
    unawaited(refreshBattery());
    Timer(const Duration(seconds: 5), _checkSubUpdates);
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
          // Older builds could store several profiles under one id (timestamp
          // collisions while parsing a subscription) — repairing keeps each
          // server individually selectable.
          final repaired = ProfileIds.repair(profiles);
          if (repaired > 0) {
            await _secure.write(
              key: 'way.profiles',
              value: json.encode(profiles.map((p) => p.toJson()).toList()),
            );
            debugPrint('repaired $repaired duplicate profile id(s)');
          }
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
      'dyn': dynamicColors,
      'locale': localeCode,
      'autoupdate': autoUpdate,
      'updatemin': autoUpdateMin,
      'dnshost': dnsHost,
      'dnsstrategy': dnsStrategy,
      'tlsfragment': tlsFragment,
      'mux': muxProtocol,
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
      'autoreconnect': autoReconnect,
      'desktopnotify': desktopNotify,
      'checkupdates': autoCheckUpdates,
      'closetray': closeToTray,
      'localapi': localApi,
      'localapiport': localApiPort,
      'rules': customRules.map((r) => r.toJson()).toList(),
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
    if (isDesktop) {
      try {
        final b = bridge;
        if (b is DesktopBridge) await b.pollDeepLink();
      } catch (_) {}
    }
    final s = await bridge.status();
    if (s.phase != vpn.phase || (s.error != null && s.error != vpn.error)) {
      if (vpn.phase == VpnPhase.connecting && s.phase == VpnPhase.connected) {
        log('connected');
        unawaited(_fetchConnInfo());
      }
      if (vpn.phase != VpnPhase.stopped && s.phase == VpnPhase.stopped) {
        log('disconnected');
        stats = WayStats.zero;
        statsPoller.reset();
        connIp = null;
        connCountry = null;
      }
      vpn = s;
      notifyListeners();
    }
    // --- auto-reconnect watchdog bookkeeping ---
    if (s.phase == VpnPhase.connected) {
      _connectingSince = null;
      _reconnectAttempt = 0;
    } else if (s.phase == VpnPhase.connecting) {
      _connectingSince ??= DateTime.now();
      final stuck =
          DateTime.now().difference(_connectingSince!) > ReconnectPolicy.connectingStuckAfter;
      if (stuck) {
        log('watchdog: connecting stuck, forcing reconnect cycle');
        _connectingSince = null;
        unawaited(_forceCycle());
      }
    }
    if (s.phase == VpnPhase.stopped && _userWantsConnected && _reconnectTimer == null) {
      _scheduleReconnect();
    }
    final connected = vpn.phase == VpnPhase.connected;
    if (connected && _statsTimer == null) {
      _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) => _statsTick());
    } else if (!connected && _statsTimer != null) {
      _statsTimer?.cancel();
      _statsTimer = null;
    }
    unawaited(tray.update(
      phase: vpn.phase,
      l10n: L10n(effectiveLocale),
      serverName: effectiveProfile?.name,
      downMbps: vpn.phase == VpnPhase.connected
          ? stats.downSpeed * 8 / 1e6
          : null,
      upMbps: vpn.phase == VpnPhase.connected ? stats.upSpeed * 8 / 1e6 : null,
    ));
  }

  /// Tears the core down without clearing the reconnect intent, so the
  /// watchdog can rebuild the session afterwards.
  Future<void> _forceCycle() async {
    try {
      await bridge.disconnect();
    } catch (_) {}
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
  }

  void _scheduleReconnect({bool afterError = false}) {
    if (!autoReconnect || !_userWantsConnected) return;
    if (_reconnectTimer != null) return;
    if (ReconnectPolicy.fatalErrors.contains(vpn.error)) {
      _userWantsConnected = false;
      return;
    }
    if (afterError && _reconnectAttempt >= ReconnectPolicy.maxErrorAttempts) {
      log('watchdog: gave up after ${_reconnectAttempt + 1} failed attempts');
      _userWantsConnected = false;
      return;
    }
    final delay = afterError
        ? ReconnectPolicy.errorDelay(_reconnectAttempt)
        : ReconnectPolicy.dropDelay(_reconnectAttempt);
    final attempt = _reconnectAttempt + 1;
    _reconnectAttempt = attempt;
    log('watchdog: reconnect in ${delay.inSeconds}s (attempt $attempt)');
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (!_userWantsConnected || vpn.phase != VpnPhase.stopped) return;
      unawaited(connect());
    });
  }

  Future<void> _statsTick() async {
    if (vpn.phase != VpnPhase.connected) return;
    stats = await statsPoller.fetch();
    notifyListeners();
  }

  Future<void> _fetchConnInfo() async {
    if (_ipFetching) return;
    final profile = effectiveProfile;
    if (profile == null) return;
    _ipFetching = true;
    try {
      final info = await bridge.ipInfo(profile: profile, timeout: const Duration(seconds: 8));
      if (info != null) {
        if (info['ip']?.isNotEmpty == true) connIp = info['ip'];
        if (info['country']?.isNotEmpty == true) connCountry = info['country'];
      }
    } catch (_) {
    } finally {
      _ipFetching = false;
      notifyListeners();
    }
  }

  void _checkSubUpdates() {
    if (!autoUpdate || autoUpdateMin <= 0) return;
    final now = DateTime.now();
    for (final sub in List<Subscription>.from(subs)) {
      final interval = sub.updateIntervalMin > 0 ? sub.updateIntervalMin : autoUpdateMin;
      final last = sub.lastUpdate;
      if (last == null || now.difference(last).inMinutes >= interval) {
        unawaited(updateSubscription(sub));
      }
    }
  }

  Future<void> connect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    var profile = selected;
    if (autoSelect) {
      final best = bestProfile;
      if (best != null) profile = best;
    }
    if (profile == null) {
      vpn = const VpnStatus(error: 'no_profile');
      _userWantsConnected = false;
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
        _userWantsConnected = false;
        notifyListeners();
        return;
      }
    }
    final groupPool = autoSelect && engine == 'singbox'
        ? engineProfiles.where((p) => p.protocol != 'wireguard').toList()
        : const <Profile>[];
    final group = groupPool.length > 1 ? groupPool : const <Profile>[];
    Profile? chainProfile;
    if (group.isEmpty &&
        engine == 'singbox' &&
        profile.chainTo?.isNotEmpty == true) {
      for (final c in profiles) {
        if (c.id == profile.chainTo &&
            c.id != profile.id &&
            c.supportedOn('singbox')) {
          chainProfile = c;
          break;
        }
      }
    }
    log('connecting via ${profile.name} ($engine)');
    _userWantsConnected = true;
    _connectingSince = DateTime.now();
    vpn = const VpnStatus(phase: VpnPhase.connecting);
    notifyListeners();
    final tun = isDesktop ? (preferTun || killSwitch) : preferTun;
    if (!isDesktop && tun && batteryIgnored == false && !(_prefs?.getBool('way.batt_asked') ?? false)) {
      await _prefs?.setBool('way.batt_asked', true);
      pendingBatteryAsk = true;
      notifyListeners();
    }
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
      customRules: List.unmodifiable(customRules),
      chain: chainProfile,
      dnsHost: dnsHost,
      dnsStrategy: dnsStrategy,
      tlsFragment: tlsFragment,
      muxProtocol: muxProtocol,
      watchdog: autoReconnect,
    ));
    _connectingSince = null;
    if (result.error != null) {
      log('error: ${result.error}');
      vpn = VpnStatus(error: result.error);
      notifyListeners();
      _scheduleReconnect(afterError: true);
      return;
    }
    vpn = result;
    _reconnectAttempt = 0;
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
    _userWantsConnected = false;
    _connectingSince = null;
    _cancelReconnect();
    vpn = const VpnStatus(phase: VpnPhase.disconnecting);
    notifyListeners();
    await bridge.disconnect();
    stats = WayStats.zero;
    statsPoller.reset();
    connIp = null;
    connCountry = null;
    vpn = await bridge.status();
    notifyListeners();
    if (desktopNotify) {
      showDesktopToast('Way', _ru ? 'Отключено' : 'Disconnected');
    }
  }

  void handleDeepLink(String raw) {
    var url = raw.trim().replaceAll('\n', '').replaceAll('\r', '');
    if (url.isEmpty) return;
    var fromWay = false;
    if (url.toLowerCase().startsWith('way://')) {
      fromWay = true;
      var rest = url.substring(6);
      if (rest.toLowerCase().startsWith('import/')) rest = rest.substring(7);
      try {
        rest = Uri.decodeFull(rest);
      } catch (_) {}
      url = rest.trim();
    }
    if (url.isEmpty) {
      log('deep link ignored: empty payload');
      return;
    }
    // QR transfer payload: way://import/<base64url of newline-joined links>
    if (fromWay && !url.contains('://')) {
      final before = profiles.length;
      addFromLink(url);
      lastImportCount = profiles.length - before;
      lastImportWasSub = false;
      pendingTab = 1;
      notifyListeners();
      return;
    }
    if (!url.contains('://')) {
      log('deep link ignored: unsupported format');
      return;
    }
    final scheme = url.split('://').first.toLowerCase();
    if (_wrapperSchemes.contains(scheme)) {
      try {
        final uri = Uri.parse(url);
        final target = uri.queryParameters['url'] ??
            uri.queryParameters['remote'] ??
            uri.queryParameters['u'] ?? '';
        if (target.isNotEmpty) {
          log('deep link: unwrapping $scheme');
          handleDeepLink(target);
          return;
        }
      } catch (_) {}
      log('deep link ignored: no url in $scheme wrapper');
      return;
    }
    lastImportWasSub = scheme == 'http' || scheme == 'https';
    if (lastImportWasSub) {
      var host = '';
      try {
        host = Uri.parse(url).host;
      } catch (_) {}
      addSubscription(url, host.isEmpty ? 'Subscription' : host);
      lastImportCount = 0;
      log('deep link: subscription from ${host.isEmpty ? 'url' : host}');
    } else {
      final before = profiles.length;
      addFromLink(url);
      lastImportCount = profiles.length - before;
      log('deep link: $lastImportCount profile(s)');
    }
    pendingTab = 1;
    notifyListeners();
  }

  void consumeDeepLinkTab() {
    if (pendingTab < 0) return;
    pendingTab = -1;
    notifyListeners();
  }

  void addFromLink(String link, {String subId = ''}) {
    var parsed = LinkParser.parseMany(link);
    if (parsed.isEmpty) {
      parsed = SubFormats.parseAny(link);
    }
    ProfileIds.ensureUnique(parsed, existingIds: {
      for (final p in profiles) p.id,
    });
    for (final p in parsed) {
      p.subId = subId;
      profiles.add(p);
    }
    if (selectedId == null && profiles.isNotEmpty) selectedId = profiles.first.id;
    log('added ${parsed.length} profile(s)');
    _persist();
    notifyListeners();
  }

  void addProfile(Profile p) {
    ProfileIds.ensureUnique([p], existingIds: {
      for (final other in profiles) other.id,
    });
    profiles.add(p);
    selectedId ??= p.id;
    _persist();
    notifyListeners();
  }

  Future<void> addWarp() async {
    final p = await WarpService.register();
    profiles.add(p);
    selectedId ??= p.id;
    await _persist();
    log('WARP ready: ${p.server}:${p.port}');
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
    // Guard against overlapping refreshes of the same subscription (manual
    // tap + auto-update timer) — two interleaved fetches would duplicate the
    // profile list.
    if (_updatingSubs.contains(sub.id)) return;
    _updatingSubs.add(sub.id);
    try {
      final fetched = await subsService.fetch(
        sub,
        userAgent: subUserAgent,
        hwid: hwid,
      );
      // Keep ids stable for servers that survived the refresh: selection,
      // latency cache and chain links stay attached to the same server.
      String fingerprint(Profile p) =>
          '${p.protocol}|${p.server}|${p.port}|${p.uuid ?? ''}|${p.password ?? ''}';
      final oldIdsByFp = {
        for (final p in profiles.where((p) => p.subId == sub.id))
          fingerprint(p): p.id,
      };
      for (final p in fetched) {
        final stable = oldIdsByFp[fingerprint(p)];
        if (stable != null) p.id = stable;
      }
      ProfileIds.ensureUnique(
        fetched,
        existingIds: {
          for (final p in profiles.where((p) => p.subId != sub.id)) p.id,
        },
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
    } finally {
      _updatingSubs.remove(sub.id);
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
    final results = await LatencyTester.testAll(
      targets,
      bridge,
      concurrency: isDesktop ? 6 : 3,
    );
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

  // --- server list: favorites / search / sort -------------------------------

  void toggleFavorite(String id) {
    for (final p in profiles) {
      if (p.id == id) p.favorite = !p.favorite;
    }
    _persist();
    notifyListeners();
  }

  void setServerQuery(String value) {
    serverQuery = value.trim();
    notifyListeners();
  }

  void setServerSort(String value) {
    serverSort = value;
    _persist();
    notifyListeners();
  }

  /// Profiles filtered by the search query and ordered: favorites pinned on
  /// top, then the chosen sort mode. Selection order inside equals groups is
  /// kept stable so the engine sees the same list.
  List<Profile> get visibleProfiles {
    Iterable<Profile> list = profiles;
    final q = serverQuery.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) =>
          p.name.toLowerCase().contains(q) ||
          p.server.toLowerCase().contains(q) ||
          p.protocolLabel.toLowerCase().contains(q));
    }
    final result = list.toList();
    int Function(Profile, Profile) compare;
    switch (serverSort) {
      case 'latency':
        compare = (a, b) {
          final la = latencies[a.id];
          final lb = latencies[b.id];
          if (la == null && lb == null) return 0;
          if (la == null) return 1;
          if (lb == null) return -1;
          return la.compareTo(lb);
        };
        break;
      case 'name':
        compare = (a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase());
        break;
      default:
        compare = (a, b) => 0;
    }
    if (serverSort != 'default') result.sort(compare);
    // Favorites always float to the top, preserving the inner order.
    result.sort((a, b) => (b.favorite ? 1 : 0) - (a.favorite ? 1 : 0));
    return result;
  }

  // --- speed test ------------------------------------------------------------

  Future<void> runSpeedTest() async {
    if (speedTesting) return;
    speedTesting = true;
    speedtestMbps = null;
    notifyListeners();
    try {
      final mbps = await SpeedTester.measure();
      speedtestMbps = mbps;
      log(mbps == null
          ? 'speedtest failed'
          : 'speedtest: ${mbps.toStringAsFixed(1)} Mbps');
    } catch (_) {
      speedtestMbps = null;
    } finally {
      speedTesting = false;
      notifyListeners();
    }
  }

  // --- clipboard sniffer -----------------------------------------------------

  static const _clipSchemes = [
    'vless://', 'vmess://', 'ss://', 'trojan://', 'hysteria2://', 'hy2://',
    'tuic://', 'anytls://', 'way://', 'https://', 'clash://', 'sing-box://',
  ];

  Future<void> sniffClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty ||
          text.length > 8192 ||
          text == _lastClipboardSeen ||
          _dismissedClipboard.contains(text)) {
        return;
      }
      final lower = text.toLowerCase();
      if (!_clipSchemes.any(lower.startsWith)) return;
      // Subscriptions and plain config links both qualify; anything already
      // sitting in the profiles list is ignored.
      if (profiles.any((p) => LinkBuilder.build(p) == text)) return;
      _lastClipboardSeen = text;
      pendingClipboard = text;
      notifyListeners();
    } catch (_) {}
  }

  String? _lastClipboardSeen;

  void acceptClipboardImport() {
    final text = pendingClipboard;
    pendingClipboard = null;
    if (text == null) return;
    handleDeepLink(text);
  }

  void dismissClipboardImport() {
    final text = pendingClipboard;
    pendingClipboard = null;
    if (text != null) {
      _dismissedClipboard.add(text);
      while (_dismissedClipboard.length > 8) {
        _dismissedClipboard.remove(_dismissedClipboard.first);
      }
    }
    notifyListeners();
  }

  // --- file import (Clash YAML / sing-box JSON / link lists) ------------------

  Future<void> importFromFile() async {
    final raw = await FileFormats.pickText();
    if (raw == null) return;
    final before = profiles.length;
    addFromLink(raw);
    lastImportCount = profiles.length - before;
    lastImportWasSub = false;
    pendingTab = -1;
    log('file import: $lastImportCount profile(s)');
    notifyListeners();
  }

  // --- local HTTP API ---------------------------------------------------------

  Future<void> startLocalApi() async {
    try {
      apiToken ??= _genUuidV4();
      try {
        await _secure.write(key: 'way.apitoken', value: apiToken!);
      } catch (_) {}
      await localApiServer.start(localApiPort, apiToken ?? '');
      log('local api on 127.0.0.1:$localApiPort');
    } catch (e) {
      log('local api failed: $e');
    }
    notifyListeners();
  }

  Future<void> stopLocalApi() async {
    await localApiServer.stop();
    log('local api stopped');
    notifyListeners();
  }

  Future<void> setLocalApi(bool value) async {
    localApi = value;
    _persist();
    notifyListeners();
    if (value) {
      await startLocalApi();
    } else {
      await stopLocalApi();
    }
  }

  void setLocalApiPort(int value) {
    localApiPort = value <= 0 ? 20718 : value;
    if (localApi) unawaited(startLocalApi());
    _persist();
    notifyListeners();
  }

  void removeProfile(String id) {
    profiles.removeWhere((p) => p.id == id);
    if (selectedId == id) selectedId = profiles.isNotEmpty ? profiles.first.id : null;
    for (final p in profiles) {
      if (p.chainTo == id) p.chainTo = null;
    }
    _persist();
    notifyListeners();
  }

  void setChain(String profileId, String? targetId) {
    for (final p in profiles) {
      if (p.id == profileId) p.chainTo = targetId;
    }
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

  void setDynamicColors(bool value) {
    dynamicColors = value;
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

  void setUpdateInterval(int minutes) {
    autoUpdateMin = minutes;
    _persist();
    notifyListeners();
  }

  void setDnsHost(String value) {
    final v = value.trim();
    dnsHost = v.isEmpty
        ? '1.1.1.1'
        : (v.startsWith('https://') ? Uri.tryParse(v)?.host ?? v : v);
    if (dnsHost.isEmpty) dnsHost = '1.1.1.1';
    _persist();
    notifyListeners();
  }

  void setDnsStrategy(String value) {
    dnsStrategy = value;
    _persist();
    notifyListeners();
  }

  void setTlsFragment(bool value) {
    tlsFragment = value;
    _persist();
    notifyListeners();
  }

  void setMux(String value) {
    muxProtocol = value;
    _persist();
    notifyListeners();
  }

  Future<void> refreshBattery() async {
    if (isDesktop) return;
    try {
      batteryIgnored = await bridge.batteryIgnored();
    } catch (_) {
      batteryIgnored = null;
    }
    notifyListeners();
  }

  Future<void> requestBatteryIgnore() async {
    await bridge.requestBatteryIgnore();
    await Future.delayed(const Duration(seconds: 2));
    await refreshBattery();
  }

  void consumeBatteryAsk() {
    if (!pendingBatteryAsk) return;
    pendingBatteryAsk = false;
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

  void setAutoReconnect(bool value) {
    autoReconnect = value;
    if (!value) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    } else if (_userWantsConnected && vpn.phase == VpnPhase.stopped) {
      _reconnectAttempt = 0;
      _scheduleReconnect();
    }
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

  void setCloseToTray(bool value) {
    closeToTray = value;
    _persist();
    notifyListeners();
    unawaited(tray.setCloseToTray(value));
  }

  Future<void> setOnboardingDone() async {
    onboardingDone = true;
    try {
      await _prefs?.setBool('way.intro_done', true);
    } catch (_) {}
    notifyListeners();
  }

  void addRule(RouteRule rule) {
    customRules = [...customRules, rule];
    _persist();
    notifyListeners();
  }

  void removeRule(String id) {
    customRules = customRules.where((r) => r.id != id).toList();
    _persist();
    notifyListeners();
  }

  Map<String, dynamic> _backupSettings() => {
        'engine': engine,
        'tun': preferTun,
        'theme': themeMode,
        'dyn': dynamicColors,
        'locale': localeCode,
        'autoupdate': autoUpdate,
        'updatemin': autoUpdateMin,
        'dnshost': dnsHost,
        'dnsstrategy': dnsStrategy,
        'tlsfragment': tlsFragment,
        'mux': muxProtocol,
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
        'autoreconnect': autoReconnect,
        'desktopnotify': desktopNotify,
        'checkupdates': autoCheckUpdates,
        'closetray': closeToTray,
        'rules': customRules.map((r) => r.toJson()).toList(),
      };

  Future<bool> exportBackup() async {
    final content = BackupService.buildJson(
      _backupSettings(),
      profiles.map((p) => p.toJson()).toList(),
      subs.map((s) => s.toJson()).toList(),
    );
    return BackupService.export(content, BackupService.defaultName());
  }

  Future<bool> importBackup() async {
    final raw = await BackupService.import();
    if (raw == null) return false;
    final data = BackupService.parse(raw);
    if (data == null) return false;
    try {
      final importedProfiles = (data['profiles'] as List)
          .map((e) => Profile.fromJson(e as Map<String, dynamic>))
          .where((p) => p.protocol.isNotEmpty && p.server.isNotEmpty)
          .toList();
      final importedSubs = ((data['subscriptions'] as List?) ?? const [])
          .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
          .toList();
      final settings = data['settings'] as Map<String, dynamic>;
      profiles = importedProfiles;
      subs = importedSubs;
      selectedId = settings['selected'] as String?;
      engine = settings['engine'] as String? ?? engine;
      preferTun = settings['tun'] as bool? ?? preferTun;
      themeMode = settings['theme'] as String? ?? themeMode;
      dynamicColors = settings['dyn'] as bool? ?? dynamicColors;
      localeCode = settings['locale'] as String? ?? localeCode;
      autoUpdate = settings['autoupdate'] as bool? ?? autoUpdate;
      autoUpdateMin = (settings['updatemin'] as num?)?.toInt() ?? autoUpdateMin;
      dnsHost = settings['dnshost'] as String? ?? dnsHost;
      dnsStrategy = settings['dnsstrategy'] as String? ?? dnsStrategy;
      tlsFragment = settings['tlsfragment'] as bool? ?? tlsFragment;
      muxProtocol = settings['mux'] as String? ?? muxProtocol;
      routingMode = settings['routing'] as String? ?? routingMode;
      blockAds = settings['blockads'] as bool? ?? blockAds;
      killSwitch = settings['killswitch'] as bool? ?? killSwitch;
      splitMode = settings['splitmode'] as String? ?? splitMode;
      splitApps =
          (settings['splitapps'] as List?)?.cast<String>() ?? splitApps;
      subUserAgent = settings['subua'] as String? ?? subUserAgent;
      autoSelect = settings['autoselect'] as bool? ?? autoSelect;
      autoStart = settings['autostart'] as bool? ?? autoStart;
      connectOnLaunch = settings['connectlaunch'] as bool? ?? connectOnLaunch;
      autoReconnect = settings['autoreconnect'] as bool? ?? autoReconnect;
      desktopNotify = settings['desktopnotify'] as bool? ?? desktopNotify;
      autoCheckUpdates = settings['checkupdates'] as bool? ?? autoCheckUpdates;
      closeToTray = settings['closetray'] as bool? ?? closeToTray;
      customRules = (settings['rules'] as List?)
              ?.map((e) => RouteRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          customRules;
      latencies = {};
      unawaited(tray.setCloseToTray(closeToTray));
      await _persist();
      log('backup restored: ${profiles.length} profile(s)');
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
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
      // Read at most the last 256 KB — the screen refreshes every second and
      // a long session can grow the log to many megabytes.
      const maxBytes = 256 * 1024;
      RandomAccessFile? raf;
      try {
        raf = file.openSync();
        final size = raf.lengthSync();
        final start = size > maxBytes ? size - maxBytes : 0;
        raf.setPositionSync(start);
        var content = utf8.decode(raf.readSync(size - start), allowMalformed: true);
        if (start > 0) {
          final nl = content.indexOf('\n');
          if (nl >= 0) content = content.substring(nl + 1);
        }
        var all = content.split('\n');
        while (all.isNotEmpty && all.last.isEmpty) {
          all.removeLast();
        }
        return all.length <= lines ? all : all.sublist(all.length - lines);
      } finally {
        raf?.closeSync();
      }
    } catch (_) {
      return const [];
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _subsTimer?.cancel();
    _statsTimer?.cancel();
    _reconnectTimer?.cancel();
    _clipboardTimer?.cancel();
    unawaited(localApiServer.stop());
    statsPoller.dispose();
    super.dispose();
  }
}
