import 'dart:convert';

import 'profile.dart';

class WayPorts {
  static const mixed = 2080;
  static const xraySocks = 18081;
  static const xrayHttp = 18082;
  static const clashApi = 19090;
  static const controlApi = 20717;
}

class RouteRule {
  final String id;
  final String type;
  final String value;
  final String action;

  const RouteRule({
    required this.id,
    required this.type,
    required this.value,
    required this.action,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'value': value,
        'action': action,
      };

  factory RouteRule.fromJson(Map<String, dynamic> j) => RouteRule(
        id: j['id'] as String? ?? '',
        type: j['type'] as String? ?? 'suffix',
        value: j['value'] as String? ?? '',
        action: j['action'] as String? ?? 'proxy',
      );

  List<Map<String, dynamic>> toSingBox() {
    final values = value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (values.isEmpty) return const [];
    final entry = <String, dynamic>{};
    switch (type) {
      case 'keyword':
        entry['domain_keyword'] = values;
        break;
      case 'domain':
        entry['domain'] = values;
        break;
      case 'ip':
        entry['ip_cidr'] = values;
        break;
      case 'port':
        final ports = values.map(int.tryParse).whereType<int>().toList();
        if (ports.isEmpty) return const [];
        entry['port'] = ports;
        break;
      default:
        entry['domain_suffix'] = values;
    }
    if (action == 'block') {
      entry['action'] = 'reject';
    } else {
      entry['outbound'] = action;
    }
    return [entry];
  }
}

class RoutingSettings {
  final String mode;
  final bool blockAds;
  final String splitMode;
  final List<String> splitApps;
  final List<RouteRule> customRules;

  const RoutingSettings({
    this.mode = 'global',
    this.blockAds = false,
    this.splitMode = 'off',
    this.splitApps = const [],
    this.customRules = const [],
  });
}

class ConfigBuilder {
  static const tunName = 'way_tun';

  static Map<String, dynamic> singBoxConfig(
    Profile p, {
    required bool tun,
    required String logPath,
    RoutingSettings routing = const RoutingSettings(),
    List<Profile> group = const [],
    Profile? chain,
    String dnsHost = '1.1.1.1',
    String dnsStrategy = 'prefer_ipv4',
    bool tlsFragment = false,
    String muxProtocol = '',
  }) {
    final members = group.isEmpty ? [p] : group;
    final outbounds = <Map<String, dynamic>>[];
    final endpoints = <Map<String, dynamic>>[];
    final tags = <String>[];
    if (chain != null && members.length == 1) {
      outbounds.add(_singBoxOutbound(chain,
          tag: 'chain', tlsFragment: tlsFragment, mux: muxProtocol));
    }
    if (p.protocol == 'wireguard' && members.length == 1) {
      final endpoint = _wireguardEndpoint(p, 'proxy');
      if (chain != null) endpoint['dialer_proxy'] = 'chain';
      endpoints.add(endpoint);
    } else {
      for (var i = 0; i < members.length; i++) {
        final tag = members.length == 1 ? 'proxy' : 's$i';
        final outbound = _singBoxOutbound(members[i],
            tag: tag, tlsFragment: tlsFragment, mux: muxProtocol);
        if (i == 0 && members.length == 1 && chain != null) {
          outbound['dialer_proxy'] = 'chain';
        }
        outbounds.add(outbound);
        tags.add(tag);
      }
    }
    if (members.length > 1) {
      outbounds.add({
        'type': 'urltest',
        'tag': 'proxy',
        'outbounds': tags,
        'url': 'https://www.gstatic.com/generate_204',
        'interval': '3m0s',
        'tolerance': 50,
      });
    }
    outbounds.add(_directOutbound());
    return _singboxShell(
      logPath: logPath,
      tun: tun,
      outbounds: outbounds,
      routing: routing,
      endpoints: endpoints,
      dnsHost: dnsHost,
      dnsStrategy: dnsStrategy,
    );
  }

  static Map<String, dynamic> bridgeConfig({
    required bool tun,
    required String logPath,
  }) {
    return _singboxShell(
      logPath: logPath,
      tun: tun,
      outbounds: [
        {
          'type': 'socks',
          'tag': 'proxy',
          'server': '127.0.0.1',
          'server_port': WayPorts.xraySocks,
          'version': '5',
        },
        _directOutbound(),
      ],
    );
  }

  static List<Map<String, dynamic>> _ruleSets(RoutingSettings r) {
    final sets = <Map<String, dynamic>>[];
    Map<String, dynamic> remote(String tag, String url) => {
      'type': 'remote',
      'tag': tag,
      'format': 'binary',
      'url': url,
      'download_detour': 'direct',
      'update_interval': '24h',
    };
    if (r.blockAds) {
      sets.add(remote(
        'geosite-ads',
        'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs',
      ));
    }
    if (r.mode == 'ru') {
      sets.add(remote(
        'geosite-ru',
        'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ru.srs',
      ));
      sets.add(remote(
        'geoip-ru',
        'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs',
      ));
    }
    return sets;
  }

  static Map<String, dynamic> probeSingBoxConfig(Profile p, int port) {
    final endpoints = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> outbounds;
    if (p.protocol == 'wireguard') {
      endpoints.add(_wireguardEndpoint(p, 'proxy'));
      outbounds = [_directOutbound()];
    } else {
      outbounds = [
        _singBoxOutbound(p, tag: 'proxy'),
        _directOutbound(),
      ];
    }
    return {
      'log': {'level': 'warn'},
      'dns': {
        'servers': [
          {'type': 'udp', 'tag': 'dns-direct', 'server': '8.8.8.8'},
          {
            'type': 'https',
            'tag': 'dns-proxy',
            'server': '1.1.1.1',
            'detour': 'proxy',
          },
        ],
        'final': 'dns-proxy',
        'strategy': 'prefer_ipv4',
        'independent_cache': true,
      },
      'inbounds': [
        {
          'type': 'mixed',
          'tag': 'mixed-in',
          'listen': '127.0.0.1',
          'listen_port': port,
        },
      ],
      if (endpoints.isNotEmpty) 'endpoints': endpoints,
      'outbounds': outbounds,
      'route': {
        'final': 'proxy',
        'default_domain_resolver': {'server': 'dns-direct'},
      },
    };
  }

  static Map<String, dynamic> probeXrayConfig(Profile p, int port) {
    return {
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'tag': 'socks-in',
          'listen': '127.0.0.1',
          'port': port,
          'protocol': 'socks',
          'settings': {'auth': 'noauth', 'udp': false},
        },
      ],
      'outbounds': [
        _xrayOutbound(p),
        {'protocol': 'freedom', 'tag': 'direct'},
      ],
      'routing': {'domainStrategy': 'AsIs', 'rules': []},
    };
  }

  static Map<String, dynamic> xrayConfig(Profile p, {required String logPath}) {
    return {
      'log': {
        'loglevel': 'warning',
        'access': logPath,
        'error': logPath,
      },
      'inbounds': [
        {
          'tag': 'socks-in',
          'listen': '127.0.0.1',
          'port': WayPorts.xraySocks,
          'protocol': 'socks',
          'settings': {'auth': 'noauth', 'udp': true},
        },
        {
          'tag': 'http-in',
          'listen': '127.0.0.1',
          'port': WayPorts.xrayHttp,
          'protocol': 'http',
          'settings': {},
        },
      ],
      'outbounds': [
        _xrayOutbound(p),
        {'protocol': 'freedom', 'tag': 'direct'},
      ],
      'routing': {'domainStrategy': 'AsIs', 'rules': []},
    };
  }

  static Map<String, dynamic> _singboxShell({
    required String logPath,
    required bool tun,
    required List<Map<String, dynamic>> outbounds,
    RoutingSettings routing = const RoutingSettings(),
    List<Map<String, dynamic>> endpoints = const [],
    String dnsHost = '1.1.1.1',
    String dnsStrategy = 'prefer_ipv4',
  }) {
    final inbounds = <Map<String, dynamic>>[];
    if (tun) {
      inbounds.add({
        'type': 'tun',
        'tag': 'tun-in',
        'interface_name': tunName,
        'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
        'mtu': 9000,
        'auto_route': true,
        'strict_route': true,
        'stack': 'mixed',
      });
    } else {
      inbounds.add({
        'type': 'mixed',
        'tag': 'mixed-in',
        'listen': '127.0.0.1',
        'listen_port': WayPorts.mixed,
      });
    }
    final dnsRules = <Map<String, dynamic>>[];
    if (routing.mode == 'ru') {
      dnsRules.add({
        'rule_set': ['geosite-ru'],
        'server': 'dns-direct',
      });
    }
    final rules = <Map<String, dynamic>>[
      {'action': 'sniff'},
      {'protocol': 'dns', 'action': 'hijack-dns'},
    ];
    if (routing.blockAds) {
      rules.add({
        'rule_set': ['geosite-ads'],
        'action': 'reject',
      });
    }
    final splitApps = routing.splitMode == 'off' || routing.splitApps.isEmpty
        ? const <String>[]
        : routing.splitApps;
    if (splitApps.isNotEmpty) {
      if (routing.splitMode == 'include') {
        rules.add({'process_name': splitApps, 'outbound': 'proxy'});
      } else {
        rules.add({'process_name': splitApps, 'outbound': 'direct'});
      }
    }
    for (final rule in routing.customRules) {
      rules.addAll(rule.toSingBox());
    }
    if (routing.mode == 'ru') {
      rules.add({
        'rule_set': ['geosite-ru', 'geoip-ru'],
        'outbound': 'direct',
      });
    }
    final finalOutbound =
        splitApps.isNotEmpty && routing.splitMode == 'include' ? 'direct' : 'proxy';
    return {
      'log': {'level': 'info', 'timestamp': true, 'output': logPath},
      'dns': {
        'servers': [
          {'type': 'udp', 'tag': 'dns-direct', 'server': '8.8.8.8'},
          {
            'type': 'https',
            'tag': 'dns-proxy',
            'server': dnsHost.isEmpty ? '1.1.1.1' : dnsHost,
            'detour': 'proxy',
          },
        ],
        if (dnsRules.isNotEmpty) 'rules': dnsRules,
        'final': 'dns-proxy',
        'strategy':
            dnsStrategy.isEmpty ? 'prefer_ipv4' : dnsStrategy,
        'independent_cache': true,
      },
      'inbounds': inbounds,
      if (endpoints.isNotEmpty) 'endpoints': endpoints,
      'outbounds': outbounds,
      'route': {
        'rules': rules,
        if (_ruleSets(routing).isNotEmpty) 'rule_set': _ruleSets(routing),
        'final': finalOutbound,
        'auto_detect_interface': true,
        'default_domain_resolver': {'server': 'dns-direct'},
      },
      'experimental': {
        'clash_api': {'external_controller': '127.0.0.1:${WayPorts.clashApi}'},
      },
    };
  }

  static Map<String, dynamic> _directOutbound() =>
      {'type': 'direct', 'tag': 'direct'};

  static Map<String, dynamic> _wireguardEndpoint(Profile p, String tag) {
    var extra = const <String, dynamic>{};
    if (p.extra?.isNotEmpty == true) {
      try {
        final decoded = json.decode(p.extra!);
        if (decoded is Map<String, dynamic>) extra = decoded;
      } catch (_) {}
    }
    final reserved = (extra['reserved'] as List?)
            ?.map((e) => (e is num) ? e.toInt() : int.tryParse('$e') ?? 0)
            .toList() ??
        const [0, 0, 0];
    final v4 = extra['address_v4'] as String? ?? '';
    final v6 = extra['address_v6'] as String? ?? '';
    final address = [
      if (v4.isNotEmpty) v4,
      if (v6.isNotEmpty) v6,
    ];
    return {
      'type': 'wireguard',
      'tag': tag,
      if (address.isNotEmpty) 'address': address,
      'private_key': p.password ?? '',
      'mtu': 1280,
      'peers': [
        {
          'address': p.server,
          'port': p.port,
          'public_key': p.publicKey ?? '',
          'allowed_ips': ['0.0.0.0/0', '::/0'],
          'reserved': reserved,
        }
      ],
    };
  }

  static Map<String, dynamic> _singBoxOutbound(Profile p,
      {String tag = 'proxy', bool tlsFragment = false, String mux = ''}) {
    final out = <String, dynamic>{
      'type': p.protocol,
      'tag': tag,
      'server': p.server,
      'server_port': p.port,
    };
    switch (p.protocol) {
      case 'vless':
        out['uuid'] = p.uuid ?? '';
        if (p.flow?.isNotEmpty == true) out['flow'] = p.flow;
        final tls = _singBoxTls(p, allowUtls: true, fragment: tlsFragment);
        if (tls != null) out['tls'] = tls;
        final transport = _singBoxTransport(p);
        if (transport != null) out['transport'] = transport;
        break;
      case 'vmess':
        out['uuid'] = p.uuid ?? '';
        out['security'] = p.security ?? 'auto';
        out['alter_id'] = p.alterId;
        final tls = _singBoxTls(p, allowUtls: true, fragment: tlsFragment);
        if (tls != null) out['tls'] = tls;
        final transport = _singBoxTransport(p);
        if (transport != null) out['transport'] = transport;
        break;
      case 'trojan':
        out['password'] = p.password ?? '';
        final tls = _singBoxTls(p, allowUtls: true, fragment: tlsFragment);
        if (tls != null) out['tls'] = tls;
        final transport = _singBoxTransport(p);
        if (transport != null) out['transport'] = transport;
        break;
      case 'shadowsocks':
        out['method'] = p.method ?? 'aes-256-gcm';
        out['password'] = p.password ?? '';
        break;
      case 'hysteria2':
        out['password'] = p.password ?? '';
        if (p.upMbps != null) out['up_mbps'] = p.upMbps;
        if (p.downMbps != null) out['down_mbps'] = p.downMbps;
        out['tls'] = {
          'enabled': true,
          'server_name': p.sni?.isNotEmpty == true ? p.sni : p.server,
          'insecure': p.insecure,
        };
        break;
      case 'tuic':
        out['uuid'] = p.uuid ?? '';
        out['password'] = p.password ?? '';
        out['congestion_control'] = p.congestion ?? 'bbr';
        out['tls'] = {
          'enabled': true,
          'server_name': p.sni?.isNotEmpty == true ? p.sni : p.server,
          'insecure': p.insecure,
          'alpn': ['h3'],
        };
        break;
      case 'anytls':
        out['password'] = p.password ?? '';
        out['tls'] = {
          'enabled': true,
          'server_name': p.sni?.isNotEmpty == true ? p.sni : p.server,
          'insecure': p.insecure,
          if (p.alpn?.isNotEmpty == true) 'alpn': p.alpn!.split(','),
          if (p.fingerprint?.isNotEmpty == true)
            'utls': {'enabled': true, 'fingerprint': p.fingerprint},
        };
        break;
    }
    if (mux.isNotEmpty &&
        const {'vless', 'vmess', 'trojan', 'shadowsocks'}.contains(p.protocol)) {
      out['multiplex'] = {
        'enabled': true,
        'protocol': mux,
        'max_connections': 4,
        'min_streams': 4,
        'padding': true,
      };
    }
    return out;
  }

  static Map<String, dynamic>? _singBoxTls(Profile p,
      {required bool allowUtls, bool fragment = false}) {
    final needTls = p.protocol == 'trojan' ||
        p.protocol == 'hysteria2' ||
        p.protocol == 'tuic' ||
        p.publicKey?.isNotEmpty == true ||
        p.sni?.isNotEmpty == true;
    if (!needTls) return null;
    final tls = <String, dynamic>{
      'enabled': true,
      'server_name': p.sni?.isNotEmpty == true ? p.sni : p.server,
      'insecure': p.insecure,
    };
    if (p.alpn?.isNotEmpty == true) {
      tls['alpn'] = p.alpn!.split(',');
    }
    if (allowUtls && p.fingerprint?.isNotEmpty == true) {
      tls['utls'] = {'enabled': true, 'fingerprint': p.fingerprint};
    }
    if (p.publicKey?.isNotEmpty == true) {
      tls['reality'] = {
        'enabled': true,
        'public_key': p.publicKey,
        'short_id': p.shortId ?? '',
      };
    }
    if (fragment && p.protocol != 'hysteria2' && p.protocol != 'tuic') {
      tls['fragment'] = true;
      if (tls['utls'] is! Map) {
        tls['utls'] = {'enabled': true, 'fingerprint': 'chrome'};
      }
    }
    return tls;
  }

  static Map<String, dynamic>? _singBoxTransport(Profile p) {
    switch (p.network) {
      case 'ws':
        return {
          'type': 'ws',
          'path': p.path?.isNotEmpty == true ? p.path : '/',
          if (p.host?.isNotEmpty == true)
            'headers': {'Host': p.host},
        };
      case 'grpc':
        final serviceName = (p.path ?? '').replaceAll('/', '');
        return {
          'type': 'grpc',
          'service_name': serviceName,
        };
      case 'http':
        return {
          'type': 'http',
          'path': p.path?.isNotEmpty == true ? p.path : '/',
          if (p.host?.isNotEmpty == true)
            'headers': {'Host': p.host},
        };
      default:
        return null;
    }
  }

  static Map<String, dynamic> _xrayOutbound(Profile p) {
    final settings = <String, dynamic>{};
    final stream = <String, dynamic>{
      'network': _xrayNetwork(p),
      'security': _xraySecurity(p),
    };

    switch (p.protocol) {
      case 'vless':
        settings['vnext'] = [
          {
            'address': p.server,
            'port': p.port,
            'users': [
              {
                'id': p.uuid ?? '',
                'encryption': 'none',
                if (p.flow?.isNotEmpty == true) 'flow': p.flow,
                'level': 0,
              }
            ],
          }
        ];
        break;
      case 'vmess':
        settings['vnext'] = [
          {
            'address': p.server,
            'port': p.port,
            'users': [
              {
                'id': p.uuid ?? '',
                'alterId': p.alterId,
                'security': p.security ?? 'auto',
                'level': 0,
              }
            ],
          }
        ];
        break;
      case 'trojan':
        settings['servers'] = [
          {'address': p.server, 'port': p.port, 'password': p.password ?? '', 'level': 0},
        ];
        break;
      case 'shadowsocks':
        settings['servers'] = [
          {
            'address': p.server,
            'port': p.port,
            'method': p.method ?? 'aes-256-gcm',
            'password': p.password ?? '',
          }
        ];
        return {'protocol': 'shadowsocks', 'tag': 'proxy', 'settings': settings};
      default:
        settings['vnext'] = [];
    }

    _applyXrayStream(p, stream);
    return {
      'protocol': p.protocol,
      'tag': 'proxy',
      'settings': settings,
      'streamSettings': stream,
    };
  }

  static String _xrayNetwork(Profile p) {
    switch (p.network) {
      case 'ws':
        return 'ws';
      case 'grpc':
        return 'grpc';
      case 'http':
        return 'http';
      case 'xhttp':
        return 'xhttp';
      default:
        return 'tcp';
    }
  }

  static String _xraySecurity(Profile p) {
    if (p.publicKey?.isNotEmpty == true) return 'reality';
    if (p.protocol == 'trojan' ||
        p.protocol == 'hysteria2' ||
        p.protocol == 'tuic' ||
        p.sni?.isNotEmpty == true) {
      return 'tls';
    }
    return 'none';
  }

  static void _applyXrayStream(Profile p, Map<String, dynamic> stream) {
    final security = stream['security'] as String;
    if (security == 'tls') {
      stream['tlsSettings'] = {
        'serverName': p.sni?.isNotEmpty == true ? p.sni : p.server,
        if (p.fingerprint?.isNotEmpty == true) 'fingerprint': p.fingerprint,
        'allowInsecure': p.insecure,
        if (p.alpn?.isNotEmpty == true) 'alpn': p.alpn!.split(','),
      };
    } else if (security == 'reality') {
      stream['realitySettings'] = {
        'serverName': p.sni?.isNotEmpty == true ? p.sni : p.server,
        'fingerprint': p.fingerprint?.isNotEmpty == true ? p.fingerprint : 'chrome',
        'publicKey': p.publicKey,
        'shortId': p.shortId ?? '',
        'spiderX': '/',
      };
    }
    switch (stream['network'] as String) {
      case 'ws':
        stream['wsSettings'] = {
          'path': p.path?.isNotEmpty == true ? p.path : '/',
          if (p.host?.isNotEmpty == true)
            'headers': {'Host': p.host},
        };
        break;
      case 'grpc':
        stream['grpcSettings'] = {
          'serviceName': (p.path ?? '').replaceAll('/', ''),
        };
        break;
      case 'http':
        stream['httpSettings'] = {
          'path': p.path?.isNotEmpty == true ? p.path : '/',
          'host': [if (p.host?.isNotEmpty == true) p.host!],
        };
        break;
      case 'xhttp':
        stream['xhttpSettings'] = {
          'path': p.path?.isNotEmpty == true ? p.path : '/',
          if (p.host?.isNotEmpty == true) 'host': p.host,
          if (p.mode?.isNotEmpty == true) 'mode': p.mode,
          if (p.extra?.isNotEmpty == true) 'extra': _decodeJson(p.extra!),
        };
        break;
    }
  }

  static Map<String, dynamic>? _decodeJson(String raw) {
    try {
      final value = json.decode(raw);
      if (value is Map<String, dynamic>) return value;
    } catch (_) {}
    return null;
  }
}
