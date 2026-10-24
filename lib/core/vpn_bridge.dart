import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'config_builder.dart';
import 'profile.dart';

enum VpnPhase { stopped, connecting, connected, disconnecting }

class VpnStatus {
  final VpnPhase phase;
  final String? error;

  const VpnStatus({this.phase = VpnPhase.stopped, this.error});

  VpnStatus copyWith({VpnPhase? phase, String? error}) =>
      VpnStatus(phase: phase ?? this.phase, error: error ?? this.error);
}

class ConnectRequest {
  final String engine;
  final bool tun;
  final Profile profile;
  final List<Profile> group;
  final String logPath;
  final bool killSwitch;
  final String routingMode;
  final bool blockAds;
  final String splitMode;
  final List<String> splitApps;
  final List<RouteRule> customRules;
  final Profile? chain;

  const ConnectRequest({
    required this.engine,
    required this.tun,
    required this.profile,
    this.group = const [],
    required this.logPath,
    this.killSwitch = false,
    this.routingMode = 'global',
    this.blockAds = false,
    this.splitMode = 'off',
    this.splitApps = const [],
    this.customRules = const [],
    this.chain,
  });

  RoutingSettings get _routing => RoutingSettings(
        mode: routingMode,
        blockAds: blockAds,
        splitMode: splitMode,
        splitApps: splitApps,
        customRules: customRules,
      );
}

abstract class VpnBridge {
  Future<VpnStatus> connect(ConnectRequest request);
  Future<void> disconnect();
  Future<VpnStatus> status();
  Future<bool> autostartEnabled();
  Future<void> setAutostart(bool value);
  Future<String?> takePendingLink();
  void setDeepLinkHandler(void Function(String url)? handler);
  bool get tunSupported;
  Future<int?> urlTest({required Profile profile, required Duration timeout}) async => null;
}

Future<int> freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

class AndroidBridge implements VpnBridge {
  static const _channel = MethodChannel('way/core');

  @override
  bool get tunSupported => true;

  @override
  void setDeepLinkHandler(void Function(String url)? handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'on_link' && call.arguments is String) {
        handler?.call(call.arguments as String);
      }
      return null;
    });
  }

  @override
  Future<String?> takePendingLink() async {
    try {
      final link = await _channel.invokeMethod('take_link');
      if (link is String && link.contains('://')) return link;
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<VpnStatus> connect(ConnectRequest request) async {
    final body = <String, String>{
      'engine': request.engine,
      'singbox': json.encode(ConfigBuilder.singBoxConfig(
        request.profile,
        tun: true,
        logPath: request.logPath,
        routing: RoutingSettings(
          mode: request.routingMode,
          blockAds: request.blockAds,
          customRules: request.customRules,
        ),
        group: request.group,
        chain: request.chain,
      )),
      'xray': json.encode(ConfigBuilder.xrayConfig(request.profile, logPath: request.logPath)),
      'bridge': json.encode(ConfigBuilder.bridgeConfig(tun: true, logPath: request.logPath)),
      'routing_mode': request.routingMode,
      'block_ads': request.blockAds ? '1' : '0',
      'split_mode': request.splitMode,
      'split_apps': request.splitApps.join(','),
    };
    try {
      final result = await _channel
          .invokeMethod('start', body)
          .timeout(const Duration(seconds: 45));
      final granted = result is Map && result['started'] == true;
      if (!granted) {
        return const VpnStatus(error: 'vpn_permission_denied');
      }
      return const VpnStatus(phase: VpnPhase.connecting);
    } on PlatformException catch (e) {
      return VpnStatus(error: e.message ?? e.code);
    } on TimeoutException {
      return const VpnStatus(error: 'start_timeout');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('stop');
    } on PlatformException {
      return;
    }
  }

  @override
  Future<VpnStatus> status() async {
    try {
      final result = await _channel.invokeMethod('status');
      if (result is Map) {
        final state = '${result['state']}';
        final error = result['error'] as String?;
        switch (state) {
          case 'started':
            return VpnStatus(phase: VpnPhase.connected, error: error);
          case 'starting':
            return const VpnStatus(phase: VpnPhase.connecting);
          case 'stopping':
            return const VpnStatus(phase: VpnPhase.disconnecting);
          default:
            return VpnStatus(error: error);
        }
      }
      return const VpnStatus();
    } on PlatformException {
      return const VpnStatus();
    }
  }

  @override
  Future<bool> autostartEnabled() async {
    try {
      final result = await _channel.invokeMethod('autostart');
      return result is Map && result['enabled'] == true;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> setAutostart(bool value) async {
    try {
      await _channel.invokeMethod('set_autostart', {'enabled': value});
    } on PlatformException {
      return;
    }
  }

  @override
  Future<int?> urlTest({required Profile profile, required Duration timeout}) async {
    final port = await freePort();
    try {
      final engine = profile.supportedOn('singbox') ? 'singbox' : 'xray';
      final body = <String, dynamic>{
        'port': port,
        'timeout': timeout.inMilliseconds,
        if (engine == 'singbox')
          'singbox': json.encode(ConfigBuilder.probeSingBoxConfig(profile, port))
        else
          'xray': json.encode(ConfigBuilder.probeXrayConfig(profile, port)),
      };
      final result = await _channel
          .invokeMethod('url_test', body)
          .timeout(timeout + const Duration(seconds: 10));
      if (result is Map) {
        return (result['ms'] as num?)?.toInt();
      }
      return -1;
    } on PlatformException {
      return -1;
    } on TimeoutException {
      return -1;
    }
  }
}

class DesktopBridge implements VpnBridge {
  static const _base = 'http://127.0.0.1:${WayPorts.controlApi}';

  @override
  bool get tunSupported => true;

  Future<bool> _ping() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      final req = await client.getUrl(Uri.parse('$_base/ping'));
      final res = await req.close();
      final ok = res.statusCode == 200;
      client.close();
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensureCore() async {
    if (await _ping()) return true;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    var corePath = '$exeDir/waycore.exe';
    if (!Platform.isWindows && !File(corePath).existsSync()) {
      corePath = '$exeDir/waycore';
    }
    if (!File(corePath).existsSync()) return false;
    await Process.start(corePath, [], mode: ProcessStartMode.detached);
    for (var i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (await _ping()) return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final req = await client.getUrl(Uri.parse('$_base$path'));
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      client.close();
      if (res.statusCode != 200) return null;
      return json.decode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<VpnStatus> connect(ConnectRequest request) async {
    if (!await _ensureCore()) {
      return const VpnStatus(error: 'waycore_not_found');
    }
    final payload = <String, dynamic>{
      'engine': request.engine,
      'mode': request.tun ? 'tun' : 'proxy',
      'kill_switch': request.killSwitch,
    };
    if (request.engine == 'singbox') {
      payload['config'] = ConfigBuilder.singBoxConfig(
        request.profile,
        tun: request.tun,
        logPath: request.logPath,
        routing: request._routing,
        group: request.group,
        chain: request.chain,
      );
      payload['system_proxy'] = !request.tun;
      payload['system_proxy_port'] = WayPorts.mixed;
    } else {
      payload['config'] = ConfigBuilder.xrayConfig(request.profile, logPath: request.logPath);
      if (request.tun) {
        payload['bridge'] = ConfigBuilder.bridgeConfig(tun: true, logPath: request.logPath);
      }
      payload['system_proxy'] = !request.tun;
      payload['system_proxy_port'] = WayPorts.xrayHttp;
    }
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
      final req = await client.postUrl(Uri.parse('$_base/start'));
      req.headers.set('Content-Type', 'application/json');
      req.add(utf8.encode(json.encode(payload)));
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      client.close();
      if (res.statusCode != 200) {
        return VpnStatus(error: text);
      }
      return const VpnStatus(phase: VpnPhase.connecting);
    } catch (e) {
      return VpnStatus(error: e.toString());
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final req = await client.postUrl(Uri.parse('$_base/stop'));
      await req.close();
      client.close();
    } catch (_) {
      return;
    }
  }

  @override
  Future<VpnStatus> status() async {
    final data = await _get('/status');
    if (data == null) return const VpnStatus();
    if (data['running'] == true) {
      return const VpnStatus(phase: VpnPhase.connected);
    }
    final err = data['error'] as String?;
    return VpnStatus(error: err?.isEmpty == true ? null : err);
  }

  @override
  Future<bool> autostartEnabled() async {
    if (!await _ensureCore()) return false;
    final data = await _get('/autostart');
    return data?['enabled'] == true;
  }

  @override
  Future<int?> urlTest({required Profile profile, required Duration timeout}) async {
    if (!await _ensureCore()) return null;
    final port = await freePort();
    try {
      final engine = profile.supportedOn('singbox') ? 'singbox' : 'xray';
      final payload = <String, dynamic>{
        'port': port,
        'timeout': timeout.inMilliseconds,
        if (engine == 'singbox')
          'singbox': json.encode(ConfigBuilder.probeSingBoxConfig(profile, port))
        else
          'xray': json.encode(ConfigBuilder.probeXrayConfig(profile, port)),
      };
      final client = HttpClient()..connectionTimeout = timeout;
      final req = await client
          .postUrl(Uri.parse('$_base/urltest'))
          .timeout(timeout + const Duration(seconds: 10));
      req.headers.set('Content-Type', 'application/json');
      req.add(utf8.encode(json.encode(payload)));
      final res = await req.close().timeout(timeout + const Duration(seconds: 10));
      final text = await res.transform(utf8.decoder).join();
      client.close();
      if (res.statusCode != 200) return -1;
      final data = json.decode(text) as Map<String, dynamic>;
      return (data['ms'] as num?)?.toInt();
    } catch (_) {
      return -1;
    }
  }

  String? _mailboxPath() {
    final appdata = Platform.environment['LOCALAPPDATA'];
    if (appdata == null || appdata.isEmpty) return null;
    return '$appdata\\way\\import.url';
  }

  @override
  Future<String?> takePendingLink() async {
    final path = _mailboxPath();
    if (path == null) return null;
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      final content = f.readAsStringSync().trim();
      try {
        f.deleteSync();
      } catch (_) {}
      if (content.contains('://')) return content;
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  void setDeepLinkHandler(void Function(String url)? handler) {
    _deepLinkHandler = handler;
  }

  void Function(String)? _deepLinkHandler;

  Future<void> pollDeepLink() async {
    final link = await takePendingLink();
    if (link != null) {
      _deepLinkHandler?.call(link);
    }
  }

  @override
  Future<void> setAutostart(bool value) async {
    if (!await _ensureCore()) return;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final req = await client.postUrl(Uri.parse('$_base/autostart'));
      req.headers.set('Content-Type', 'application/json');
      req.add(utf8.encode(json.encode({'enabled': value})));
      await req.close();
      client.close();
    } catch (_) {
      return;
    }
  }
}

VpnBridge createBridge() {
  if (Platform.isAndroid) return AndroidBridge();
  return DesktopBridge();
}
