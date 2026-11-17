import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// User-imported fonts, Chumpy-style: a ttf/otf lands in the app's fonts
/// folder, is registered at runtime under the file's sanitized name and
/// becomes selectable app-wide. Inter stays the built-in default.
abstract final class FontRegistry {
  static const maxBytes = 20 * 1024 * 1024;
  static const _exts = {'ttf', 'otf'};

  static Future<Directory> _dir() async {
    final docs = await getApplicationSupportDirectory();
    return Directory('${docs.path}/fonts')..createSync(recursive: true);
  }

  /// Stable family id from a file name: basename without extension, path
  /// characters and anything exotic replaced.
  static String familyOf(String path) {
    final base = path.split(Platform.pathSeparator).last;
    final dot = base.lastIndexOf('.');
    final stem = dot <= 0 ? base : base.substring(0, dot);
    return stem.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_').trim().isEmpty
        ? 'font'
        : stem.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_').trim();
  }

  static Future<List<String>> imported() async {
    final dir = await _dir();
    final names = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      if (!_exts.contains(entity.path.split('.').last.toLowerCase())) continue;
      names.add(familyOf(entity.path));
    }
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  /// Copies, validates (by actually loading) and registers a font.
  /// Throws StateError('not_font') / StateError('too_large').
  static Future<String> importFrom(String sourcePath) async {
    final ext = sourcePath.split('.').last.toLowerCase();
    if (!_exts.contains(ext)) throw StateError('not_font');
    final source = File(sourcePath);
    if (await source.length() > maxBytes) throw StateError('too_large');
    final bytes = await source.readAsBytes();
    final family = familyOf(sourcePath);
    try {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    } catch (_) {
      throw StateError('not_font');
    }
    final dir = await _dir();
    await File('${dir.path}/$family.$ext').writeAsBytes(bytes, flush: true);
    return family;
  }

  /// Registers every saved font at startup; failures are silent: the app
  /// just falls back to Inter for that family until a clean re-import.
  static Future<void> loadAll(List<String> families) async {
    final dir = await _dir();
    for (final family in families) {
      File? file;
      for (final ext in _exts) {
        final candidate = File('${dir.path}/$family.$ext');
        if (candidate.existsSync()) {
          file = candidate;
          break;
        }
      }
      if (file == null) continue;
      try {
        final bytes = await file.readAsBytes();
        final loader = FontLoader(family)
          ..addFont(Future.value(ByteData.view(bytes.buffer)));
        await loader.load();
      } catch (_) {}
    }
  }

  static Future<void> delete(String family) async {
    final dir = await _dir();
    for (final ext in _exts) {
      final file = File('${dir.path}/$family.$ext');
      if (file.existsSync()) file.deleteSync();
    }
  }
}
