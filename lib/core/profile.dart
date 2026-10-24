class Profile {
  String id;
  String name;
  String protocol;
  String server;
  int port;
  String? uuid;
  String? password;
  String? method;
  String? flow;
  String? network;
  String? path;
  String? host;
  String? sni;
  String? fingerprint;
  String? publicKey;
  String? shortId;
  bool insecure;
  String? alpn;
  String? security;
  int alterId;
  String? congestion;
  int? upMbps;
  int? downMbps;
  String? mode;
  String? extra;
  String subId;
  String? chainTo;

  Profile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.server,
    required this.port,
    this.uuid,
    this.password,
    this.method,
    this.flow,
    this.network,
    this.path,
    this.host,
    this.sni,
    this.fingerprint,
    this.publicKey,
    this.shortId,
    this.insecure = false,
    this.alpn,
    this.security,
    this.alterId = 0,
    this.congestion,
    this.upMbps,
    this.downMbps,
    this.mode,
    this.extra,
    this.subId = '',
    this.chainTo,
  });

  String get protocolLabel {
    switch (protocol) {
      case 'shadowsocks':
        return 'SS';
      case 'hysteria2':
        return 'HY2';
      case 'vmess':
        return 'VMESS';
      case 'vless':
        return 'VLESS';
      case 'trojan':
        return 'TROJAN';
      case 'tuic':
        return 'TUIC';
      default:
        return protocol.toUpperCase();
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'protocol': protocol,
    'server': server,
    'port': port,
    'uuid': uuid,
    'password': password,
    'method': method,
    'flow': flow,
    'network': network,
    'path': path,
    'host': host,
    'sni': sni,
    'fingerprint': fingerprint,
    'public_key': publicKey,
    'short_id': shortId,
    'insecure': insecure,
    'alpn': alpn,
    'security': security,
    'alter_id': alterId,
    'congestion': congestion,
    'up_mbps': upMbps,
    'down_mbps': downMbps,
    'mode': mode,
    'extra': extra,
    'sub_id': subId,
    if (chainTo != null) 'chain_to': chainTo,
  };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    protocol: j['protocol'] as String? ?? '',
    server: j['server'] as String? ?? '',
    port: (j['port'] as num?)?.toInt() ?? 0,
    uuid: j['uuid'] as String?,
    password: j['password'] as String?,
    method: j['method'] as String?,
    flow: j['flow'] as String?,
    network: j['network'] as String?,
    path: j['path'] as String?,
    host: j['host'] as String?,
    sni: j['sni'] as String?,
    fingerprint: j['fingerprint'] as String?,
    publicKey: j['public_key'] as String?,
    shortId: j['short_id'] as String?,
    insecure: j['insecure'] as bool? ?? false,
    alpn: j['alpn'] as String?,
    security: j['security'] as String?,
    alterId: (j['alter_id'] as num?)?.toInt() ?? 0,
    congestion: j['congestion'] as String?,
    upMbps: (j['up_mbps'] as num?)?.toInt(),
    downMbps: (j['down_mbps'] as num?)?.toInt(),
    mode: j['mode'] as String?,
    extra: j['extra'] as String?,
    subId: j['sub_id'] as String? ?? '',
    chainTo: j['chain_to'] as String?,
  );

  bool supportedOn(String engine) {
    if (protocol == 'hysteria2' ||
        protocol == 'tuic' ||
        protocol == 'wireguard' ||
        protocol == 'anytls') {
      return engine == 'singbox';
    }
    if (network == 'xhttp') return engine == 'xray';
    return true;
  }

  bool get needsTls =>
      protocol == 'trojan' ||
      protocol == 'hysteria2' ||
      protocol == 'tuic' ||
      (protocol == 'vless' && (sni?.isNotEmpty == true || network == 'ws' || network == 'grpc' || flow?.isNotEmpty == true)) ||
      (protocol == 'vmess' && (sni?.isNotEmpty == true));
}
