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
  String get deleteSubConfirm =>
      ru ? 'Удалить подписку вместе с её серверами?' : 'Delete this subscription and its servers?';
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
  String get tunHintAndroid => ru
      ? 'TUN — полноценный VPN. Прокси — локальный socks/http 127.0.0.1:2080 без VPN-разрешения, настраивается в приложениях вручную.'
      : 'TUN is a full VPN. Proxy exposes local socks/http on 127.0.0.1:2080 without VPN permission — configure apps manually.';
  String get appearance => ru ? 'Внешний вид' : 'Appearance';
  String get themeSystem => ru ? 'Системная' : 'System';
  String get themeLight => ru ? 'Светлая' : 'Light';
  String get themeDark => ru ? 'Тёмная' : 'Dark';
  String get materialYou => ru ? 'Цвета Material You' : 'Material You colors';
  String get materialYouHint =>
      ru ? 'Окрашивать интерфейс в цвета системы (Android 12+)' : 'Tint the UI with system colors (Android 12+)';
  String get language => ru ? 'Язык' : 'Language';
  String get langSystem => ru ? 'Системный' : 'System';
  String get updates => ru ? 'Подписки' : 'Subscriptions';
  String get autoUpdate => ru ? 'Автообновление' : 'Auto-update';
  String get updateInterval => ru ? 'Интервал обновления' : 'Update interval';
  String _intervalLabel(int m) {
    if (m >= 1440) return ru ? 'каждые ${m ~/ 1440} сут' : 'every ${m ~/ 1440} d';
    if (m >= 60) return ru ? 'каждые ${m ~/ 60} ч' : 'every ${m ~/ 60} h';
    return ru ? 'каждые $m мин' : 'every $m min';
  }
  String intervalValue(int m) =>
      m <= 0 ? (ru ? 'Выкл' : 'Off') : _intervalLabel(m);

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

  String get autoFastest => ru ? 'Быстрейший' : 'Fastest';
  String get autoFastestHint =>
      ru ? 'Автовыбор сервера с наименьшей задержкой' : 'Auto-pick the lowest-latency server';
  String get fastest => ru ? 'Быстрейший' : 'Fastest';
  String get testLatency => ru ? 'Проверить задержку' : 'Test latency';
  String get testing => ru ? 'Проверка…' : 'Testing…';
  String get ms => ru ? 'мс' : 'ms';
  String get timeout => ru ? 'таймаут' : 'timeout';
  String get scanQr => ru ? 'Сканировать QR-код' : 'Scan QR code';
  String get cameraError => ru
      ? 'Нет доступа к камере. Разрешите камеру в настройках системы.'
      : 'No camera access. Grant camera permission in system settings.';
  String get paste => ru ? 'Вставить из буфера' : 'Paste from clipboard';
  String get subUserAgent => ru ? 'User-Agent подписки' : 'Subscription User-Agent';
  String get subUaHint => ru
      ? 'Некоторые панели отдают реальные серверы только известным клиентам. Way отправляет совместимый UA и идентификатор устройства (хранится в зашифрованном виде).'
      : 'Some panels serve real nodes only to known clients. Way sends a compatible UA and a device id (stored encrypted).';
  String get trafficLabel => ru ? 'Трафик' : 'Traffic';
  String get unlimited => ru ? 'без лимита' : 'unlimited';
  String get expiresLabel => ru ? 'до' : 'until';

  String get about => ru ? 'О приложении' : 'About';
  String get version => ru ? 'Версия' : 'Version';
  String get cores => ru ? 'Ядра' : 'Cores';
  String get license => 'GPL-3.0';

  String get appSection => ru ? 'Приложение' : 'Application';
  String get autostart => ru ? 'Автозапуск' : 'Autostart';
  String deepLinkProfiles(int n) => ru
      ? 'Импортировано профилей: $n'
      : 'Imported profiles: $n';
  String get deepLinkSub => ru ? 'Подписка добавляется' : 'Adding subscription';
  String get deepLinkInvalid => ru
      ? 'Ссылка не распознана'
      : 'Link not recognized';
  String get autostartHintDesktop => ru
      ? 'Запускать Way при входе в Windows (ключ Run в реестре).'
      : 'Start Way when you sign in to Windows (Run registry key).';
  String get autostartHintAndroid => ru
      ? 'Восстанавливать VPN после перезагрузки устройства или обновления приложения.'
      : 'Restore the VPN after device reboot or app update.';
  String get connectOnLaunch => ru ? 'Подключаться при запуске' : 'Connect on launch';
  String get connectOnLaunchHint => ru
      ? 'Автоматически подключаться, когда приложение стартует.'
      : 'Automatically connect when the app starts.';
  String get autoReconnect => ru ? 'Автопереподключение' : 'Auto-reconnect';
  String get autoReconnectHint => ru
      ? 'Watchdog следит за туннелем и восстанавливает связь после обрыва, сна или смены сети.'
      : 'Watchdog keeps the tunnel alive and restores it after drops, sleep or network changes.';
  String reconnectingAttempt(int n) =>
      ru ? 'Переподключение · попытка $n' : 'Reconnecting · attempt $n';
  String get desktopNotifications => ru ? 'Уведомления Windows' : 'Windows notifications';
  String get desktopNotificationsHint => ru
      ? 'Всплывающие уведомления при подключении и отключении.'
      : 'Popup notifications on connect and disconnect.';
  String get checkUpdates => ru ? 'Проверить обновления' : 'Check for updates';
  String get checkUpdatesHint => ru
      ? 'Сверяется с релизами GitHub и предлагает скачать новую версию.'
      : 'Checks GitHub Releases and offers to download a new version.';
  String get autoCheckUpdates => ru ? 'Проверять при запуске' : 'Check on startup';
  String get updateAvailable => ru ? 'Доступна новая версия' : 'New version available';
  String get upToDate => ru ? 'У вас последняя версия' : 'You are on the latest version';
  String get download => ru ? 'Скачать' : 'Download';
  String get later => ru ? 'Позже' : 'Later';
  String get checking => ru ? 'Проверка…' : 'Checking…';
  String get whatsNew => ru ? 'Что нового' : "What's new";
  String get currentVersion => ru ? 'Текущая версия' : 'Current version';

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

  String get total => ru ? 'Всего' : 'Total';
  String get totalIdle => ru ? 'Нет данных о трафике' : 'No traffic data';

  String get trayOpen => ru ? 'Открыть Way' : 'Open Way';
  String get trayQuit => ru ? 'Выход' : 'Quit';

  String get closeToTray => ru ? 'Сворачивать в трей' : 'Close to tray';
  String get closeToTrayHint => ru
      ? 'Закрытие окна скрывает приложение в системный трей; выход — через меню трея.'
      : 'Closing the window hides the app to the tray; quit from the tray menu.';

  String get rulesEditor => ru ? 'Правила маршрутизации' : 'Routing rules';
  String get rulesHint => ru
      ? 'Свои правила для доменов, IP и портов поверх пресетов (sing-box). Значения через запятую.'
      : 'Custom domain, IP and port rules on top of presets (sing-box). Comma-separate values.';
  String get rulesCount => ru ? 'правил' : 'rule(s)';
  String get ruleAdd => ru ? 'Добавить правило' : 'Add rule';
  String get ruleType => ru ? 'Тип' : 'Type';
  String get ruleValue => ru ? 'Значение' : 'Value';
  String get ruleTypeSuffix => ru ? 'Домен оканчивается на' : 'Domain suffix';
  String get ruleTypeKeyword => ru ? 'Домен содержит' : 'Domain keyword';
  String get ruleTypeDomain => ru ? 'Точный домен' : 'Exact domain';
  String get ruleTypeIp => ru ? 'IP или подсеть' : 'IP or CIDR';
  String get ruleTypePort => ru ? 'Порт' : 'Port';
  String get ruleProxy => ru ? 'Через VPN' : 'Via VPN';
  String get ruleDirect => ru ? 'Напрямую' : 'Direct';
  String get ruleBlock => ru ? 'Блокировать' : 'Block';

  String get dataSection => ru ? 'Данные' : 'Data';
  String get backupHint => ru
      ? 'Профили, подписки и настройки в JSON-файле. Ключи хранятся открыто — не передавайте файл третьим лицам.'
      : 'Profiles, subscriptions and settings in a JSON file. Keys are stored in plain text — do not share the file.';
  String get exportBackup => ru ? 'Экспорт резервной копии' : 'Export backup';
  String get importBackup => ru ? 'Восстановить из копии' : 'Restore from backup';
  String get backupSaved => ru ? 'Резервная копия сохранена' : 'Backup saved';
  String get backupFailed => ru ? 'Не удалось сохранить копию' : 'Failed to save backup';
  String get backupImportConfirm => ru
      ? 'Заменить текущие профили, подписки и настройки содержимым файла?'
      : 'Replace current profiles, subscriptions and settings with the file content?';
  String get backupImported => ru ? 'Резервная копия восстановлена' : 'Backup restored';
  String get backupInvalid => ru
      ? 'Некорректный файл резервной копии'
      : 'Invalid backup file';

  String get introSkip => ru ? 'Пропустить' : 'Skip';
  String get introNext => ru ? 'Далее' : 'Next';
  String get introStart => ru ? 'Начать' : 'Get started';
  String get introWelcomeTitle => ru ? 'Way — ваш маршрут в приватность' : 'Way — your route to privacy';
  String get introWelcomeText => ru
      ? 'Два ядра — sing-box и xray — в одном клиенте. VLESS, Reality, VMess, Trojan, Shadowsocks, Hysteria2 и TUIC.'
      : 'Two cores — sing-box and xray — in one client. VLESS, Reality, VMess, Trojan, Shadowsocks, Hysteria2 and TUIC.';
  String get introServersTitle => ru ? 'Добавьте сервер' : 'Add a server';
  String get introServersText => ru
      ? 'Вставьте ссылку vless://…, отсканируйте QR-код или добавьте подписку — серверы обновляются автоматически.'
      : 'Paste a vless://… link, scan a QR code or add a subscription — servers update automatically.';
  String get introDoneTitle => ru ? 'Всё готово' : 'You are set';
  String get introDoneText => ru
      ? 'Нажмите большую кнопку, чтобы подключиться. Разрешите уведомления — так VPN покажет свой статус.'
      : 'Tap the big button to connect. Allow notifications so the VPN can show its status.';

  String get autoPick => ru ? 'Авто-выбор популярных' : 'Auto-pick popular';
  String autoPickDone(int n) => ru
      ? 'Выбрано популярных приложений: $n'
      : 'Popular apps selected: $n';
  String get appsExport => ru ? 'Экспорт списка' : 'Export list';
  String get appsImport => ru ? 'Импорт списка' : 'Import list';
  String get appsImportHint => ru
      ? 'Пакеты по одному в строке или через запятую'
      : 'One package per line, or comma-separated';
  String appsImported(int n) => ru
      ? 'Добавлено пакетов: $n'
      : 'Packages added: $n';

  String get chainThrough => ru ? 'Пустить через сервер…' : 'Chain through…';
  String get chainNone => ru ? 'Без цепочки' : 'No chain';
  String get chainHint => ru
      ? 'Цепочка: трафик пойдёт через выбранный сервер поверх текущего (sing-box, недоступно в режиме «Быстрейший»).'
      : 'Chain: traffic goes through the selected server on top of the current one (sing-box, unavailable in “Fastest” mode).';

  String get dnsSection => ru ? 'DNS' : 'DNS';
  String get dnsServer => ru ? 'DNS-сервер (DoH)' : 'DNS server (DoH)';
  String get dnsServerHint => ru
      ? 'Удалённый DNS через шифрованный канал: 1.1.1.1, 8.8.8.8, dns.google…'
      : 'Remote DNS over encrypted channel: 1.1.1.1, 8.8.8.8, dns.google…';
  String get dnsStrategy => ru ? 'Стратегия адресов' : 'Address strategy';
  String get dnsAuto => ru ? 'Авто' : 'Auto';
  String get dnsPreferV4 => ru ? 'IPv4 приоритет' : 'Prefer IPv4';
  String get dnsPreferV6 => ru ? 'IPv6 приоритет' : 'Prefer IPv6';
  String get dnsOnlyV4 => 'IPv4 only';
  String get dnsOnlyV6 => 'IPv6 only';

  String get advanced => ru ? 'Продвинутые' : 'Advanced';
  String get tlsFragment => ru ? 'TLS-фрагментация' : 'TLS fragmentation';
  String get tlsFragmentHint => ru
      ? 'Нарезает ClientHello на части для обхода DPI-блокировок (sing-box, TCP-TLS).'
      : 'Splits the TLS ClientHello to bypass DPI filtering (sing-box, TCP-TLS).';
  String get mux => ru ? 'Мультиплексирование' : 'Multiplexing';
  String get muxHint => ru
      ? 'Mux-протокол для нескольких потоков в одном соединении (sing-box).'
      : 'Mux protocol to carry multiple streams in one connection (sing-box).';
  String get muxOff => ru ? 'Выкл' : 'Off';

  String get addModeLink => ru ? 'Ссылка' : 'Link';
  String get addModeManual => ru ? 'Вручную' : 'Manual';
  String get addModeJson => 'JSON';
  String get jsonHint => ru
      ? 'Вставьте JSON: sing-box outbound, {"outbounds":[…]} или массив'
      : 'Paste JSON: a sing-box outbound, {"outbounds":[…]} or an array';
  String get manualType => ru ? 'Протокол' : 'Protocol';
  String get manualServer => ru ? 'Сервер' : 'Server';
  String get manualPort => ru ? 'Порт' : 'Port';
  String get manualSecret => ru ? 'UUID или пароль' : 'UUID or password';
  String get manualSni => ru ? 'SNI (необязательно)' : 'SNI (optional)';
  String get invalidInput => ru ? 'Некорректные данные' : 'Invalid input';

  String get showQr => ru ? 'Показать QR' : 'Show QR';
  String get qrUnsupported => ru
      ? 'QR для этого протокола недоступен'
      : 'QR is not available for this protocol';

  String get warp => 'Cloudflare WARP';
  String get warpHint => ru
      ? 'Бесплатный туннель WireGuard от Cloudflare — без подписки (sing-box).'
      : 'Free Cloudflare WireGuard tunnel — no subscription needed (sing-box).';
  String get warpAdding => ru ? 'Регистрация…' : 'Registering…';
  String get warpAdded => ru ? 'WARP добавлен' : 'WARP added';
  String get warpFailed => ru
      ? 'Не удалось зарегистрировать WARP — проверьте сеть'
      : 'WARP registration failed — check your network';

  String get batteryTitle => ru ? 'Оптимизация батареи' : 'Battery optimization';
  String get batteryAllowed => ru
      ? 'Way исключён — фоновый VPN работает стабильно'
      : 'Way is excluded — background VPN runs reliably';
  String get batteryHint => ru
      ? 'Отключите оптимизацию, чтобы Android не разрывал VPN в фоне'
      : 'Exempt Way so Android does not kill the VPN in background';
  String get batteryDialogTitle => ru ? 'Оптимизация батареи' : 'Battery optimization';
  String get batteryDialogText => ru
      ? 'Разрешить Way игнорировать оптимизацию батареи? Иначе Android может обрывать VPN в фоне.'
      : 'Let Way ignore battery optimization? Otherwise Android may interrupt the VPN in the background.';
  String get batteryAsk => ru ? 'Настроить' : 'Configure';

  String errorText(String? code) {
    switch (code) {
      case 'no_profile':
        return errNoProfile;
      case 'vpn_permission_denied':
        return errPermission;
      case 'waycore_not_found':
        return errWaycore;
      case 'unsupported_profile':
        return ru
            ? 'Профиль не поддерживается доступными ядрами'
            : 'Profile is not supported by the available engines';
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
