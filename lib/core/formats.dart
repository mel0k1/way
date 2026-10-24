import 'dart:convert';

import 'package:yaml/yaml.dart';

import 'parser.dart';
import 'profile.dart';

class SubFormats {
  static bool looksJson(String text) {
    final t = text.trim();
    return t.startsWith('{') || t.startsWith('[');
  }

  static bool looksClashYaml(String text) {
    return RegExp(r'^proxies:\s*$', multiLine: true).hasMatch(text);
  }

  static List<Profile> parseAny(String text) {
    if (looksJson(text)) return parseSingboxJson(text);
    if (looksClashYaml(text)) return parseClashYaml(text);
    return const [];
  }

  static List<Profile> parseSingboxJson(String text) {
    try {
      final decoded = json.decode(text);
      final List items;
      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map && decoded['outbounds'] is List) {
        items = decoded['outbounds'] as List;
      } else {
        items = [decoded];
      }
      final result = <Profile>[];
      for (final item in items) {
        if (item is Map) {
          final p = singboxOutboundToProfile(Map<String, dynamic>.from(item));
          if (p != null) result.add(p);
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  static List<Profile> parseClashYaml(String text) {
    try {
      final doc = loadYaml(text);
      if (doc is! YamlMap) return const [];
      final proxies = doc['proxies'];
      if (proxies is! YamlList) return const [];
      final result = <Profile>[];
      for (final item in proxies) {
        if (item is YamlMap) {
          final p = clashProxyToProfile(_plainMap(item));
          if (p != null) result.add(p);
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  static Map<String, dynamic> _plainMap(YamlMap y) {
    final out = <String, dynamic>{};
    y.forEach((k, v) {
      out['$k'] = _plain(v);
    });
    return out;
  }

  static dynamic _plain(dynamic v) {
    if (v is YamlMap) {
      final out = <String, dynamic>{};
      v.forEach((k, val) => out['$k'] = _plain(val));
      return out;
    }
    if (v is YamlList) return v.map(_plain).toList();
    return v;
  }

  static String _s(dynamic v) => v == null ? '' : '$v'.trim();

  static int _intOf(dynamic v) {
    if (v == null) return 0;
    final m = RegExp(r'-?\d+').firstMatch('$v');
    return m == null ? 0 : int.parse(m.group(0)!);
  }

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    final m = RegExp(r'-?\d+').firstMatch('$v');
    return m == null ? null : int.parse(m.group(0)!);
  }

  static bool _b(dynamic v) => v == true || '$v' == 'true' || '$v' == '1';

  static List<String> _list(dynamic v) =>
      v is List ? v.map((e) => '$e').where((e) => e.isNotEmpty).toList() : const [];

  static Profile? singboxOutboundToProfile(Map<String, dynamic> m) {
    final type = _s(m['type']).toLowerCase();
    const supported = {
      'vless', 'vmess', 'trojan', 'shadowsocks', 'hysteria2', 'tuic', 'anytls',
    };
    if (!supported.contains(type)) return null;
    final server = _s(m['server']);
    final port = _intOf(m['server_port']);
    if (server.isEmpty || port <= 0) return null;
    final p = Profile(
      id: LinkParser.genId(),
      name: _s(m['tag']).isEmpty ? server : _s(m['tag']),
      protocol: type,
      server: server,
      port: port,
    );
    final tls = m['tls'] is Map
        ? Map<String, dynamic>.from(m['tls'] as Map)
        : const <String, dynamic>{};
    final transport = m['transport'] is Map
        ? Map<String, dynamic>.from(m['transport'] as Map)
        : const <String, dynamic>{};
    switch (type) {
      case 'vless':
        p.uuid = _s(m['uuid']);
        p.flow = _s(m['flow']);
        break;
      case 'vmess':
        p.uuid = _s(m['uuid']);
        p.security = _s(m['security']).isEmpty ? 'auto' : _s(m['security']);
        p.alterId = _intOf(m['alter_id']);
        break;
      case 'trojan':
        p.password = _s(m['password']);
        break;
      case 'shadowsocks':
        p.method = _s(m['method']).isEmpty ? 'aes-256-gcm' : _s(m['method']);
        p.password = _s(m['password']);
        break;
      case 'hysteria2':
        p.password = _s(m['password']);
        if (m['up_mbps'] is num) p.upMbps = (m['up_mbps'] as num).toInt();
        if (m['down_mbps'] is num) p.downMbps = (m['down_mbps'] as num).toInt();
        break;
      case 'tuic':
        p.uuid = _s(m['uuid']);
        p.password = _s(m['password']);
        p.congestion = _s(m['congestion_control']).isEmpty
            ? 'bbr'
            : _s(m['congestion_control']);
        break;
      case 'anytls':
        p.password = _s(m['password']);
        break;
    }
    if (tls['enabled'] == true || (type == 'vless' && tls.isNotEmpty)) {
      p.sni = _s(tls['server_name']);
      p.insecure = tls['insecure'] == true;
      final alpn = _list(tls['alpn']);
      if (alpn.isNotEmpty) p.alpn = alpn.join(',');
      if (tls['utls'] is Map) {
        final utls = Map<String, dynamic>.from(tls['utls'] as Map);
        if (utls['enabled'] == true) p.fingerprint = _s(utls['fingerprint']);
      }
      if (tls['reality'] is Map) {
        final reality = Map<String, dynamic>.from(tls['reality'] as Map);
        if (reality['enabled'] == true) {
          p.publicKey = _s(reality['public_key']);
          p.shortId = _s(reality['short_id']);
        }
      }
    }
    if (transport.isNotEmpty) {
      final ttype = _s(transport['type']);
      if (ttype == 'ws' || ttype == 'http' || ttype == 'httpupgrade') {
        p.network = ttype == 'httpupgrade' ? 'ws' : ttype;
        p.path = _s(transport['path']).isEmpty ? '/' : _s(transport['path']);
        if (transport['headers'] is Map) {
          final headers = Map<String, dynamic>.from(transport['headers'] as Map);
          p.host = _s(headers['Host']).isEmpty ? _s(headers['host']) : _s(headers['Host']);
        }
      } else if (ttype == 'grpc') {
        p.network = 'grpc';
        p.path = _s(transport['service_name']);
      }
    }
    return p;
  }

  static Profile? clashProxyToProfile(Map<String, dynamic> m) {
    final type = _s(m['type']).toLowerCase();
    String? protocol;
    switch (type) {
      case 'vless':
      case 'vmess':
      case 'trojan':
        protocol = type;
        break;
      case 'ss':
        protocol = 'shadowsocks';
        break;
      case 'hysteria2':
      case 'hy2':
        protocol = 'hysteria2';
        break;
      case 'tuic':
        protocol = 'tuic';
        break;
      case 'anytls':
        protocol = 'anytls';
        break;
      default:
        return null;
    }
    final server = _s(m['server']);
    final port = _intOf(m['port']);
    if (server.isEmpty || port <= 0) return null;
    final p = Profile(
      id: LinkParser.genId(),
      name: _s(m['name']).isEmpty ? server : _s(m['name']),
      protocol: protocol,
      server: server,
      port: port,
    );
    switch (protocol) {
      case 'vless':
        p.uuid = _s(m['uuid']);
        p.flow = _s(m['flow']);
        break;
      case 'vmess':
        p.uuid = _s(m['uuid']);
        p.security = _s(m['cipher']).isEmpty ? 'auto' : _s(m['cipher']);
        p.alterId = _intOf(m['alterId'] ?? m['alter-id']);
        break;
      case 'trojan':
        p.password = _s(m['password']);
        break;
      case 'shadowsocks':
        p.method = _s(m['cipher']).isEmpty ? 'aes-256-gcm' : _s(m['cipher']);
        p.password = _s(m['password']);
        break;
      case 'hysteria2':
        p.password = _s(m['password']);
        p.upMbps = _intOrNull(m['up']);
        p.downMbps = _intOrNull(m['down']);
        break;
      case 'tuic':
        p.uuid = _s(m['uuid']);
        p.password = _s(m['password']);
        p.congestion = _s(m['congestion-controller'] ?? m['congestion_control']).isEmpty
            ? 'bbr'
            : _s(m['congestion-controller'] ?? m['congestion_control']);
        break;
      case 'anytls':
        p.password = _s(m['password']);
        break;
    }
    final tlsOn = _b(m['tls']);
    final sni = _s(m['servername'] ?? m['sni']);
    if (sni.isNotEmpty) p.sni = sni;
    if (tlsOn && (p.sni == null || p.sni!.isEmpty)) p.sni = server;
    p.insecure = _b(m['skip-cert-verify']);
    p.fingerprint = _s(m['client-fingerprint']);
    final alpn = _list(m['alpn']);
    if (alpn.isNotEmpty) p.alpn = alpn.join(',');
    if (m['reality-opts'] is Map) {
      final reality = Map<String, dynamic>.from(m['reality-opts'] as Map);
      p.publicKey = _s(reality['public-key']);
      p.shortId = _s(reality['short-id']);
    }
    final network = _s(m['network']).toLowerCase();
    switch (network) {
      case 'ws':
        p.network = 'ws';
        if (m['ws-opts'] is Map) {
          final ws = Map<String, dynamic>.from(m['ws-opts'] as Map);
          p.path = _s(ws['path']).isEmpty ? '/' : _s(ws['path']);
          if (ws['headers'] is Map) {
            final headers = Map<String, dynamic>.from(ws['headers'] as Map);
            p.host = _s(headers['Host']).isEmpty ? _s(headers['host']) : _s(headers['Host']);
          }
        }
        break;
      case 'grpc':
        p.network = 'grpc';
        if (m['grpc-opts'] is Map) {
          final grpc = Map<String, dynamic>.from(m['grpc-opts'] as Map);
          p.path = _s(grpc['grpc-service-name']);
        }
        break;
      case 'h2':
        p.network = 'http';
        if (m['h2-opts'] is Map) {
          final h2 = Map<String, dynamic>.from(m['h2-opts'] as Map);
          p.path = _s(h2['path']).isEmpty ? '/' : _s(h2['path']);
          final hosts = _list(h2['host']);
          if (hosts.isNotEmpty) p.host = hosts.first;
        }
        break;
      case 'http':
        p.network = 'http';
        if (m['http-opts'] is Map) {
          final http0 = Map<String, dynamic>.from(m['http-opts'] as Map);
          p.path = _s(http0['path']).isEmpty ? '/' : _s(http0['path']);
        }
        break;
      default:
        break;
    }
    return p;
  }
}

class LinkBuilder {
  static String? build(Profile p) {
    switch (p.protocol) {
      case 'vless':
        return _vless(p);
      case 'vmess':
        return _vmess(p);
      case 'trojan':
        return _trojan(p);
      case 'shadowsocks':
        return _ss(p);
      case 'hysteria2':
        return _hysteria2(p);
      case 'tuic':
        return _tuic(p);
      case 'anytls':
        return _anytls(p);
      default:
        return null;
    }
  }

  static Map<String, String> _commonQuery(Profile p) {
    final q = <String, String>{};
    final network = (p.network?.isEmpty ?? true) ? 'tcp' : p.network!;
    q['type'] = network;
    if (p.sni?.isNotEmpty == true) {
      q['security'] = p.publicKey?.isNotEmpty == true ? 'reality' : 'tls';
      q['sni'] = p.sni!;
    } else if (p.publicKey?.isNotEmpty == true) {
      q['security'] = 'reality';
    }
    if (p.flow?.isNotEmpty == true) q['flow'] = p.flow!;
    if (p.fingerprint?.isNotEmpty == true) q['fp'] = p.fingerprint!;
    if (p.publicKey?.isNotEmpty == true) q['pbk'] = p.publicKey!;
    if (p.shortId?.isNotEmpty == true) q['sid'] = p.shortId!;
    if (p.path?.isNotEmpty == true && network != 'tcp') q['path'] = p.path!;
    if (p.host?.isNotEmpty == true) q['host'] = p.host!;
    if (p.alpn?.isNotEmpty == true) q['alpn'] = p.alpn!;
    if (p.insecure) q['allowInsecure'] = '1';
    return q;
  }

  static String _encodeQuery(Map<String, String> q) {
    return q.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
  }

  static String _fragment(String name) =>
      name.isEmpty ? '' : '#${Uri.encodeComponent(name)}';

  static String _vless(Profile p) =>
      'vless://${Uri.encodeComponent(p.uuid ?? '')}@${p.server}:${p.port}'
      '?${_encodeQuery(_commonQuery(p))}${_fragment(p.name)}';

  static String _trojan(Profile p) =>
      'trojan://${Uri.encodeComponent(p.password ?? '')}@${p.server}:${p.port}'
      '?${_encodeQuery(_commonQuery(p))}${_fragment(p.name)}';

  static String _hysteria2(Profile p) {
    final q = <String, String>{
      if (p.sni?.isNotEmpty == true) 'sni': p.sni!,
      if (p.insecure) 'insecure': '1',
    };
    return 'hysteria2://${Uri.encodeComponent(p.password ?? '')}@${p.server}:${p.port}'
        '?${_encodeQuery(q)}${_fragment(p.name)}';
  }

  static String _tuic(Profile p) {
    final q = <String, String>{
      'congestion_control': p.congestion?.isNotEmpty == true ? p.congestion! : 'bbr',
      'alpn': p.alpn?.isNotEmpty == true ? p.alpn! : 'h3',
      if (p.sni?.isNotEmpty == true) 'sni': p.sni!,
      if (p.insecure) 'allow_insecure': '1',
    };
    return 'tuic://${Uri.encodeComponent(p.uuid ?? '')}:${Uri.encodeComponent(p.password ?? '')}'
        '@${p.server}:${p.port}?${_encodeQuery(q)}${_fragment(p.name)}';
  }

  static String _anytls(Profile p) {
    final q = <String, String>{
      if (p.sni?.isNotEmpty == true) 'sni': p.sni!,
      if (p.fingerprint?.isNotEmpty == true) 'fp': p.fingerprint!,
      if (p.alpn?.isNotEmpty == true) 'alpn': p.alpn!,
      if (p.insecure) 'insecure': '1',
    };
    return 'anytls://${Uri.encodeComponent(p.password ?? '')}@${p.server}:${p.port}'
        '?${_encodeQuery(q)}${_fragment(p.name)}';
  }

  static String _b64(String s) =>
      base64Url.encode(utf8.encode(s)).replaceAll('=', '');

  static String _ss(Profile p) {
    final userinfo = _b64('${p.method ?? 'aes-256-gcm'}:${p.password ?? ''}');
    return 'ss://$userinfo@${p.server}:${p.port}${_fragment(p.name)}';
  }

  static String _vmess(Profile p) {
    final obj = json.encode({
      'v': '2',
      'ps': p.name,
      'add': p.server,
      'port': p.port,
      'id': p.uuid ?? '',
      'aid': p.alterId,
      'scy': p.security ?? 'auto',
      'net': (p.network?.isEmpty ?? true) ? 'tcp' : p.network,
      'type': 'none',
      'host': p.host ?? '',
      'path': p.path ?? '/',
      'sni': p.sni ?? '',
      'alpn': p.alpn ?? '',
      'fp': p.fingerprint ?? '',
      'tls': (p.sni?.isNotEmpty == true) ? 'tls' : '',
    });
    return 'vmess://${_b64(obj)}';
  }
}
