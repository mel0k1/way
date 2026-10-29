import 'config_builder.dart';

enum DetectKind {
  /// Rule matched — traffic leaves via the VPN.
  proxy,

  /// Rule matched — traffic bypasses the tunnel.
  direct,

  /// Rule matched — traffic is rejected.
  block,

  /// Remote rule set (geosite/geoip) — cannot be evaluated offline.
  unknown,

  /// Informational step that does not apply to a domain probe.
  skip,
}

/// One step of the routing pipeline walkthrough.
class DetectStep {
  /// Machine code: 'ads' | 'split' | 'custom' | 'ru' | 'final'.
  final String code;
  final String detail;
  final DetectKind kind;

  const DetectStep(this.code, this.detail, this.kind);
}

class DetectResult {
  final String domain;
  final bool isIp;
  final List<DetectStep> steps;

  /// The outbound the traffic would leave through: 'proxy' | 'direct' | 'block'.
  final DetectKind verdict;

  /// Which rule decided: e.g. 'domain_suffix: example.com' or 'final'.
  final String reason;

  const DetectResult({
    required this.domain,
    required this.isIp,
    required this.steps,
    required this.verdict,
    required this.reason,
  });
}

/// Client-side replay of the exact rule pipeline ConfigBuilder._singboxShell
/// emits, so a domain probe answers "where does it go?" without the core
/// running (Karing's diversion_rule_detect_screen, offline edition).
class RouteDetect {
  /// Strips scheme, userinfo, path, query, fragment and port; keeps the bare
  /// domain or IP literal (IPv6 brackets removed).
  static String normalize(String raw) {
    var v = raw.trim();
    if (v.isEmpty) return '';
    final scheme = v.indexOf('://');
    if (scheme >= 0) v = v.substring(scheme + 3);
    for (final ch in ['/', '?', '#']) {
      final i = v.indexOf(ch);
      if (i >= 0) v = v.substring(0, i);
    }
    final at = v.lastIndexOf('@');
    if (at >= 0) v = v.substring(at + 1);
    if (v.startsWith('[')) {
      final close = v.indexOf(']');
      if (close >= 0) v = v.substring(1, close);
    } else {
      final colon = v.indexOf(':');
      if (colon >= 0) v = v.substring(0, colon);
    }
    return v.trim().toLowerCase();
  }

  static bool _isIp(String v) {
    final parts = v.split('.');
    if (parts.length == 4) {
      for (final p in parts) {
        final n = int.tryParse(p);
        if (n == null || n < 0 || n > 255) return false;
      }
      return true;
    }
    // Rough IPv6: hex groups separated by colons.
    return v.contains(':') && RegExp(r'^[0-9a-f:]+$').hasMatch(v);
  }

  static int? _ipv4ToInt(String s) {
    final parts = s.split('.');
    if (parts.length != 4) return null;
    var v = 0;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return null;
      v = (v << 8) | n;
    }
    return v;
  }

  static bool _cidrContains(String cidr, String ip) {
    final slash = cidr.indexOf('/');
    if (slash < 0) return cidr == ip;
    final net = _ipv4ToInt(cidr.substring(0, slash));
    final bits = int.tryParse(cidr.substring(slash + 1)) ?? -1;
    final addr = _ipv4ToInt(ip);
    if (net == null || addr == null || bits < 0 || bits > 32) return false;
    if (bits == 0) return true;
    final mask = bits == 32
        ? 0xFFFFFFFF
        : (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF;
    return (net & mask) == (addr & mask);
  }

  static bool _matchDomain(String pattern, String domain, String type) {
    switch (type) {
      case 'domain':
        return domain == pattern;
      case 'keyword':
        return domain.contains(pattern);
      case 'ip':
        return false;
      case 'port':
        return false;
      default: // suffix
        return domain == pattern || domain.endsWith('.$pattern');
    }
  }

  static String _valuesOf(RouteRule r) =>
      r.value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  /// Replays, in the exact order the sing-box config lists them, every
  /// decision the core will make for [input].
  static DetectResult run(String input, RoutingSettings r) {
    final domain = normalize(input);
    final isIp = _isIp(domain);
    final steps = <DetectStep>[];
    if (domain.isEmpty) {
      return DetectResult(
          domain: '', isIp: false, steps: const [], verdict: DetectKind.unknown, reason: '');
    }

    // 1. Ad blocking — a remote geosite list, not checkable offline.
    if (r.blockAds) {
      steps.add(const DetectStep(
        'ads',
        'geosite-category-ads-all',
        DetectKind.unknown,
      ));
    }

    // 2. Process-based split tunneling — not applicable to a domain probe.
    final splitApps = r.splitMode == 'off' || r.splitApps.isEmpty
        ? const <String>[]
        : r.splitApps;
    if (splitApps.isNotEmpty) {
      steps.add(DetectStep(
        'split',
        r.splitMode == 'include'
            ? '${splitApps.length} process(es) → proxy'
            : '${splitApps.length} process(es) → direct',
        DetectKind.skip,
      ));
    }

    // 3. Custom rules — first match wins (sing-box route.rules order).
    for (final rule in r.customRules) {
      final values = _valuesOf(rule);
      if (values.isEmpty) continue;
      bool hit = false;
      if (rule.type == 'ip') {
        if (isIp) {
          hit = values.any((v) => _cidrContains(v, domain));
        }
      } else if (rule.type == 'port') {
        // No port in a domain probe — nothing to match.
      } else {
        hit = values.any((v) => _matchDomain(v, domain, rule.type));
      }
      final summary =
          '${_typeLabel(rule.type)}: ${values.take(3).join(', ')}'
          '${values.length > 3 ? ' +${values.length - 3}' : ''}'
          ' → ${rule.action}';
      if (hit) {
        steps.add(DetectStep('custom', summary, _kindOf(rule.action)));
        return DetectResult(
          domain: domain,
          isIp: isIp,
          steps: steps,
          verdict: _kindOf(rule.action),
          reason: summary,
        );
      }
    }
    if (r.customRules.isNotEmpty) {
      steps.add(DetectStep(
        'custom',
        '${r.customRules.length} rule(s) — no match',
        DetectKind.skip,
      ));
    }

    // 4. "RU direct" mode — remote geosite/geoip lists, not checkable offline.
    if (r.mode == 'ru') {
      steps.add(const DetectStep(
        'ru',
        'geosite-ru / geoip-ru → direct',
        DetectKind.unknown,
      ));
    }

    // 5. Default outbound (final).
    final finalOutbound =
        splitApps.isNotEmpty && r.splitMode == 'include' ? 'direct' : 'proxy';
    steps.add(DetectStep('final', 'final → $finalOutbound', _kindOf(finalOutbound)));
    return DetectResult(
      domain: domain,
      isIp: isIp,
      steps: steps,
      verdict: _kindOf(finalOutbound),
      reason: 'final',
    );
  }

  static DetectKind _kindOf(String action) {
    switch (action) {
      case 'direct':
        return DetectKind.direct;
      case 'block':
        return DetectKind.block;
      default:
        return DetectKind.proxy;
    }
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'suffix':
        return 'domain_suffix';
      case 'keyword':
        return 'domain_keyword';
      default:
        return type;
    }
  }
}
