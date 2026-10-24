import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BackupService {
  static const _channel = MethodChannel('way/core');
  static const version = 1;

  static String buildJson(
    Map<String, dynamic> settings,
    List<dynamic> profiles,
    List<dynamic> subs,
  ) {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'way',
      'version': version,
      'exported': DateTime.now().toIso8601String(),
      'settings': settings,
      'profiles': profiles,
      'subscriptions': subs,
    });
  }

  static Map<String, dynamic>? parse(String raw) {
    try {
      final data = json.decode(raw);
      if (data is! Map<String, dynamic>) return null;
      if (data['app'] != 'way') return null;
      if (data['profiles'] is! List) return null;
      if (data['settings'] is! Map<String, dynamic>) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  static String defaultName() {
    final now = DateTime.now();
    final stamp = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    return 'way-backup-$stamp.json';
  }

  static Future<bool> export(String content, String name) async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod(
          'export_backup',
          {'name': name, 'content': content},
        );
        return res == true;
      } on PlatformException {
        return false;
      }
    }
    if (Platform.isWindows) {
      try {
        final location = await getSaveLocation(
          suggestedName: name,
          acceptedTypeGroups: const [
            XTypeGroup(label: 'JSON', extensions: ['json']),
          ],
        );
        if (location == null) return false;
        await File(location.path).writeAsString(content, flush: true);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  static Future<String?> import() async {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod<String>('import_backup');
      } on PlatformException {
        return null;
      }
    }
    if (Platform.isWindows) {
      try {
        final file = await openFile(acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json']),
        ]);
        if (file == null) return null;
        return await file.readAsString();
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
