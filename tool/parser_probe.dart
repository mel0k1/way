// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final raw = File(args[0]).readAsStringSync();
  final decoded = utf8.decode(base64.decode(raw.trim().replaceAll('\n', '')));
  final lines = LineSplitter.split(decoded);
  print('lines: ${lines.length}');
  for (final line in lines.take(3)) {
    final uri = Uri.parse(line);
    print('---');
    print('fragment raw access: ${uri.fragment}');
    print('double decode ok: ${Uri.decodeComponent(uri.fragment)}');
    print('host=${uri.host} port=${uri.port} type=${uri.queryParameters['type']}');
    print('pbk=${uri.queryParameters['pbk']} sid=${uri.queryParameters['sid']} fp=${uri.queryParameters['fp']}');
    print('mode=${uri.queryParameters['mode']} extraLen=${(uri.queryParameters['extra'] ?? '').length}');
  }
}
