import 'dart:io';

class UwpApp {
  final String family;
  final String name;

  const UwpApp(this.family, this.name);
}

class UwpLoopback {
  static bool get supported {
    try {
      return Platform.isWindows;
    } catch (_) {
      return false;
    }
  }

  static Future<List<UwpApp>> installed() async {
    try {
      final res = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          'Get-AppxPackage | '
              'Sort-Object Name | '
              'ForEach-Object { \$_.PackageFamilyName + \')\' + \$_.Name }',
        ],
        runInShell: false,
      ).timeout(const Duration(seconds: 25));
      final out = '${res.stdout}';
      final apps = <UwpApp>[];
      for (var line in out.split('\n')) {
        line = line.trim();
        if (line.isEmpty || !line.contains(')')) continue;
        final idx = line.indexOf(')');
        final family = line.substring(0, idx).trim();
        final name = line.substring(idx + 1).trim();
        if (!_looksLikeFamily(family)) continue;
        apps.add(UwpApp(family, name.isEmpty ? family : name));
      }
      return apps;
    } catch (_) {
      return const [];
    }
  }

  static Future<Set<String>> exempted() async {
    try {
      final res = await Process.run(
        'CheckNetIsolation.exe',
        const ['LoopbackExempt', '-s'],
        runInShell: false,
      ).timeout(const Duration(seconds: 15));
      final out = '${res.stdout}\n${res.stderr}';
      final result = <String>{};
      final re = RegExp(r'\b([a-z0-9][a-z0-9.\-_]*_[a-z0-9]+)\b',
          caseSensitive: false);
      for (final match in re.allMatches(out)) {
        final token = match.group(1)!;
        if (_looksLikeFamily(token)) result.add(token);
      }
      return result;
    } catch (_) {
      return <String>{};
    }
  }

  static Future<bool> exempt(String family) =>
      _runAddRemove(['LoopbackExempt', '-a', '-n=$family']);

  static Future<bool> unexempt(String family) =>
      _runAddRemove(['LoopbackExempt', '-d', '-n=$family']);

  static Future<bool> _runAddRemove(List<String> args) async {
    try {
      final res = await Process.run(
        'CheckNetIsolation.exe',
        args,
        runInShell: false,
      ).timeout(const Duration(seconds: 15));
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static bool _looksLikeFamily(String s) {
    final i = s.lastIndexOf('_');
    if (i <= 0 || i == s.length - 1) return false;
    final pkg = s.substring(0, i);
    final hash = s.substring(i + 1);
    if (pkg.contains(' ') || hash.contains(' ')) return false;
    if (pkg.length < 2 || hash.length < 3) return false;
    return RegExp(r'^[A-Za-z0-9.\-]+$').hasMatch(pkg) &&
        RegExp(r'^[A-Za-z0-9]+$').hasMatch(hash);
  }
}
