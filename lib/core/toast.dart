import 'dart:io';

Future<void> showDesktopToast(String title, String body) async {
  if (!Platform.isWindows) return;
  final script = <String>[
    '[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null',
    '[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null',
    r'$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)',
    r"$texts = $xml.GetElementsByTagName('text')",
    r"$texts.Item(0).AppendChild($xml.CreateTextNode('" + _esc(title) + r"')) | Out-Null",
    r"$texts.Item(1).AppendChild($xml.CreateTextNode('" + _esc(body) + r"')) | Out-Null",
    r'$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)',
    r"$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe')",
    r'$notifier.Show($toast)',
  ].join('; ');
  try {
    await Process.run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-Command', script],
      runInShell: false,
    );
  } catch (_) {
    return;
  }
}

String _esc(String s) => s.replaceAll("'", "''");
