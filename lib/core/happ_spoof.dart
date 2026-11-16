import 'dart:math';

/// The Happ panel's client fingerprint, ported from Chumpy's HappSpoof
/// (itself from BetterExclave): some panels serve only the official Happ
/// app, which identifies itself with the "Happ" user agent and a set of
/// x- headers — device model, OS, and the two identifiers the panel binds
/// the account to, the user id and the HWID. Both are random: nothing about
/// the real device leaks into them, and they are generated once and kept,
/// so the panel keeps seeing the same "device" across fetches and restarts.
class HappFingerprint {
  final String appVersion;
  final String os;
  final String osVersion;
  final String deviceModel;
  final String locale;
  final String userId;
  final String hwid;

  const HappFingerprint({
    required this.appVersion,
    required this.os,
    required this.osVersion,
    required this.deviceModel,
    required this.locale,
    required this.userId,
    required this.hwid,
  });

  /// The UA carries version, OS and user id; the x- headers carry the rest.
  Map<String, String> headers() => {
    'User-Agent': 'Happ/$appVersion/$os/$userId',
    'x-device-locale': locale,
    'x-hwid': hwid,
    'x-device-os': os,
    'x-ver-os': osVersion,
    'x-device-model': deviceModel,
    'accept-encoding': 'gzip',
  };
}

abstract final class HappSpoof {
  /// The Happ version the spoof claims; pinned, like a real client's would be.
  static const defaultVersion = '3.21.1';
  static final Random _rng = Random.secure();

  /// A 20-digit user id, the shape Happ's own ids carry.
  static String randomUserId() {
    final sb = StringBuffer()..write(_rng.nextInt(9) + 1);
    for (var i = 1; i < 20; i++) {
      sb.write(_rng.nextInt(10));
    }
    return sb.toString();
  }

  /// A 16-hex-character HWID.
  static String randomHwid() => List.generate(
    8,
    (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
