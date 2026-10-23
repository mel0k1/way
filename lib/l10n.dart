import 'package:flutter/widgets.dart';

class L10n {
  final String code;

  const L10n(this.code);

  bool get ru => code == 'ru';

  String get appName => 'Way';
  String get navHome => ru ? 'Главная' : 'Home';
  String get navServers => ru ? 'Серверы' : 'Servers';
  String get navLogs => ru ? 'Логи' : 'Logs';
  String get navSettings => ru ? 'Настройки' : 'Settings';

  String get connect => ru ? 'Подключить' : 'Connect';
  String get disconnect => ru ? 'Отключить' : 'Disconnect';
  String get connected => ru ? 'Подключено' : 'Connected';
  String get connecting => ru ? 'Подключение…' : 'Connecting…';
  String get disconnecting => ru ? 'Отключение…' : 'Disconnecting…';
  String get stopped => ru ? 'Отключено' : 'Disconnected';

  String get noProfileSelected => ru ? 'Профиль не выбран' : 'No profile selected';
  String get tapToConnect => ru ? 'Нажмите, чтобы подключиться' : 'Tap to connect';

  String get downSpeed => ru ? 'Приём' : 'Down';
  String get upSpeed => ru ? 'Отдача' : 'Up';
  String get connectionsLabel => ru ? 'Соединения' : 'Connections';
  String get uptime => ru ? 'Время' : 'Uptime';

  String get serversTitle => ru ? 'Серверы' : 'Servers';
  String get noServers => ru ? 'Список пуст — добавьте сервер или подписку' : 'Empty — add a server or subscription';
  String get addServer => ru ? 'Добавить сервер' : 'Add server';
  String get addSubscription => ru ? 'Добавить подписку' : 'Add subscription';
  String get linkHint => ru ? 'vless://… vmess://… ss://…' : 'vless://… vmess://… ss://…';
  String get nameLabel => ru ? 'Название' : 'Name';
  String get urlLabel => 'URL';
  String get save => ru ? 'Сохранить' : 'Save';
  String get cancel => ru ? 'Отмена' : 'Cancel';
  String get delete => ru ? 'Удалить' : 'Delete';
  String get deleteConfirm => ru ? 'Удалить этот сервер?' : 'Delete this server?';
  String get updateNow => ru ? 'Обновить' : 'Update';
  String get never => ru ? 'никогда' : 'never';
  String get entries => ru ? 'серверов' : 'entries';
  String get imported => ru ? 'Импортировано' : 'Imported';

  String get settingsTitle => ru ? 'Настройки' : 'Settings';
  String get engine => ru ? 'Ядро' : 'Core engine';
  String get engineHint => ru ? 'Протоколы hysteria2 и tuic доступны только в sing-box' : 'hysteria2 and tuic are only available via sing-box';
  String get mode => ru ? 'Режим работы' : 'Mode';
  String get modeTun => 'TUN';
  String get modeProxy => ru ? 'Прокси' : 'Proxy';
  String get tunHint => ru ? 'TUN перехватывает весь трафик (нужны права администратора на Windows). Прокси работает через системный прокси.' : 'TUN captures all traffic (requires admin on Windows). Proxy mode uses the system proxy.';
  String get appearance => ru ? 'Внешний вид' : 'Appearance';
  String get themeSystem => ru ? 'Системная' : 'System';
  String get themeLight => ru ? 'Светлая' : 'Light';
  String get themeDark => ru ? 'Тёмная' : 'Dark';
  String get language => ru ? 'Язык' : 'Language';
  String get langSystem => ru ? 'Системный' : 'System';
  String get updates => ru ? 'Подписки' : 'Subscriptions';
  String get autoUpdate => ru ? 'Автообновление (30 мин)' : 'Auto-update (30 min)';

  String get routing => ru ? 'Маршрутизация' : 'Routing';
  String get routingHint => ru
      ? '«Всё через VPN» — весь трафик через туннель. «RU напрямую» — российские сайты и IP идут мимо VPN (нужен sing-box).'
      : '“All via VPN” sends everything through the tunnel. “RU direct” keeps Russian sites and IPs outside the VPN (sing-box only).';
  String get routingGlobal => ru ? 'Всё через VPN' : 'All via VPN';
  String get routingRu => ru ? 'RU напрямую' : 'RU direct';
  String get blockAds => ru ? 'Блокировать рекламу' : 'Block ads';
  String get blockAdsHint => ru
      ? 'Блокирует рекламные домены по списку category-ads-all (sing-box)'
      : 'Blocks ad domains via the category-ads-all list (sing-box)';

  String get security => ru ? 'Безопасность' : 'Security';
  String get killSwitch => ru ? 'Kill switch' : 'Kill switch';
  String get killSwitchHintDesktop => ru
      ? 'Блокирует весь трафик мимо туннеля (WFP-фильтр). Включает режим TUN и требует права администратора.'
      : 'Blocks any traffic outside the tunnel (WFP filter). Enables TUN mode and requires administrator rights.';
  String get killSwitchHintAndroid => ru
      ? 'Включите в системе: Always-on VPN + «Блокировать соединения без VPN»'
      : 'Enable in system settings: Always-on VPN + “Block connections without VPN”';
  String get alwaysOn => ru ? 'Настройки Always-on VPN' : 'Always-on VPN settings';
  String get splitTunnel => ru ? 'Раздельное туннелирование' : 'Split tunneling';
  String get splitOff => ru ? 'Выкл' : 'Off';
  String get splitInclude => ru ? 'Только выбранные' : 'Only selected';
  String get splitExclude => ru ? 'Кроме выбранных' : 'Exclude selected';
  String get splitHintWindows => ru
      ? 'Имена процессов (exe) через запятую: chrome.exe, firefox.exe. Работает в sing-box + TUN.'
      : 'Comma-separated process (exe) names: chrome.exe, firefox.exe. Works with sing-box + TUN.';
  String get splitHintAndroid => ru
      ? 'Выберите приложения. Работает в sing-box.'
      : 'Pick apps. Works with sing-box.';
  String get splitPickApps => ru ? 'Выбрать приложения' : 'Choose apps';
  String get splitSelected => ru ? 'выбрано' : 'selected';
  String get splitProcesses => ru ? 'Процессы' : 'Processes';
  String get searchApps => ru ? 'Поиск приложений' : 'Search apps';
  String get noAppsFound => ru ? 'Ничего не найдено' : 'Nothing found';

  String get about => ru ? 'О приложении' : 'About';
  String get version => ru ? 'Версия' : 'Version';
  String get cores => ru ? 'Ядра' : 'Cores';
  String get license => 'GPL-3.0';

  String get logsTitle => ru ? 'Логи' : 'Logs';
  String get clear => ru ? 'Очистить' : 'Clear';
  String get copy => ru ? 'Копировать' : 'Copy';
  String get copied => ru ? 'Скопировано' : 'Copied';
  String get emptyLogs => ru ? 'Логи пусты' : 'No logs yet';

  String get errNoProfile => ru ? 'Сначала добавьте и выберите сервер' : 'Add and select a server first';
  String get errPermission => ru ? 'Доступ к VPN не выдан' : 'VPN permission denied';
  String get errWaycore => ru ? 'waycore.exe не найден рядом с приложением' : 'waycore.exe not found next to the app';
  String get errTunAdmin => ru ? 'Для режима TUN запустите приложение от имени администратора' : 'Run the app as administrator for TUN mode';
  String get errParse => ru ? 'Не удалось разобрать ссылку' : 'Failed to parse the link';

  String errorText(String? code) {
    switch (code) {
      case 'no_profile':
        return errNoProfile;
      case 'vpn_permission_denied':
        return errPermission;
      case 'waycore_not_found':
        return errWaycore;
      default:
        return code ?? (ru ? 'Неизвестная ошибка' : 'Unknown error');
    }
  }

  String traffic(String value) => value;
}

class L10nScope extends InheritedWidget {
  final L10n data;

  const L10nScope({super.key, required this.data, required super.child});

  static L10n of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<L10nScope>()?.data ??
      const L10n('en');

  @override
  bool updateShouldNotify(L10nScope oldWidget) => oldWidget.data.code != data.code;
}
