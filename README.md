<p align="center">
  <img src="assets/icon/banner.png" alt="Way" width="640" />
</p>

<h1 align="center">Way</h1>

<p align="center">
  <b>EN</b> · <a href="#way-на-русском">RU</a>
</p>

<p align="center">
  <a href="https://github.com/mel0k1/way/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/mel0k1/way/build.yml?branch=main&label=CI&logo=github" alt="CI" /></a>
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20Windows-brightgreen?logo=android&logoColor=white" alt="platform" />
  <img src="https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Go-1.27-00ADD8?logo=go&logoColor=white" alt="Go" />
  <img src="https://img.shields.io/badge/MD3-Material%20You-6750A4?logo=materialdesign&logoColor=white" alt="MD3" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue.svg" alt="license" /></a>
</p>

---

**Way** is a cross-platform VPN client built with **Flutter** (Material Design 3) and **Go**, powered by two engines: [sing-box](https://github.com/SagerNet/sing-box) and [Xray-core](https://github.com/XTLS/Xray-core). You can switch between cores at any moment without re-importing your servers.

## Features

- **Two cores, one app** — sing-box and xray-core live side by side; the active engine is a single tap in Settings
- **Material Design 3** — dynamic tonal palettes, squircle connect button, darkened shape background, dark & light themes
- **TUN mode** — full-device tunneling via Android VpnService and system TUN on Windows
- **Kill switch** — WFP firewall on Windows, Always-on VPN + lockdown on Android
- **Split tunneling** — per-app (Android) and per-process (Windows) tunneling rules
- **Routing presets** — “All via VPN”, “RU direct” (geosite/geoip rule-sets) and ad blocking (category-ads-all)
- **Routing rules editor** — custom domain/IP/port rules with per-rule action (via VPN, direct, block)
- **Proxy chaining** — route any server through another server (sing-box `dialer_proxy`)
- **Windows tray** — tray icon with quick connect/disconnect, close-to-tray and state-colored icon
- **Android quick settings tile** — connect/disconnect from the notification shade, restores the last used server
- **Backup & restore** — export profiles, subscriptions and settings to a JSON file (SAF on Android, save dialog on Windows)
- **Fastest server** — urltest group in sing-box and real through-proxy latency testing (a temporary core instance per server, TCP fallback) with auto-select
- **Subscriptions** — import by URL or QR code, clipboard paste, auto-refresh, panel-compatible User-Agent and quota display
- **Deep links** — tap a `vless://`/`vmess://`/`trojan://`/`ss://`/`hysteria2://`/`tuic://` link or `way://import/<url>` to import profiles and subscriptions instantly (Android and Windows)
- **Encrypted storage** — profiles and subscription keys live in flutter_secure_storage (Keystore / DPAPI)
- **Autostart** — launch on boot (Android) or user sign-in (Windows Run key), optional auto-connect on launch
- **Custom notifications** — branded Android foreground notification with a disconnect button and session timer, Windows toasts
- **Update check** — checks GitHub Releases on startup and offers to download the new build
- **RU + EN interface** — follows the system language, switchable in settings
- **Realtime stats** — live up/down speed, session traffic totals and connection counter via the clash API
- **NSIS installer** — a proper Windows setup with uninstaller, shortcuts and per-user system proxy

## Supported protocols

| Protocol | sing-box | xray |
| --- | :-: | :-: |
| VLESS (+ Reality, Vision, uTLS) | ✔ | ✔ |
| VMess | ✔ | ✔ |
| Trojan | ✔ | ✔ |
| Shadowsocks (incl. 2022) | ✔ | ✔ |
| Hysteria2 | ✔ | — |
| TUIC | ✔ | — |
| WS / gRPC / HTTP transports | ✔ | ✔ |

Links `vless://`, `vmess://`, `trojan://`, `ss://`, `hysteria2://`, `tuic://` are parsed automatically, both one by one and as a whole base64 subscription.

## Architecture

```
┌───────────────────────────── Flutter (MD3) ─────────────────────────────┐
│  home · servers · subscriptions · logs · settings (RU/EN, themes)       │
└──────────────┬───────────────────────────────────────────┬──────────────┘
               │ MethodChannel (Android)                   │ HTTP (desktop)
┌──────────────▼───────────────────┐   ┌───────────────────▼──────────────┐
│  WayVpnService (Kotlin)          │   │  waycore.exe (Go daemon)         │
│  libbox · VpnService · protect   │   │  /start /stop /status /ping      │
└──────────────┬───────────────────┘   └───────────────────┬──────────────┘
               │           ┌──────────────────────────────┐│
               └──────────►│  waycore (Go engine manager) │◄───────────────
                           │  sing-box  ──  xray-core     │
                           └──────────────────────────────┘
```

- **`core/`** — Go module `waycore`: engine manager, xray controller, HTTP control API, Windows system proxy
- **`lib/`** — Flutter app: link parser, config builder for both cores, subscriptions, MD3 UI
- **`android/`, `windows/`** — Flutter platform projects with the VpnService integration
- **`installer/`** — NSIS script for the Windows installer

## Download

Grab the latest APK and `WaySetup.exe` from [Releases](https://github.com/mel0k1/way/releases) or from the CI artifacts of every commit.

> **Windows TUN mode** requires administrator rights — run Way as administrator, otherwise use the proxy mode (system proxy is configured automatically).

## Build from source

Requirements: Go 1.27+, Flutter 3.47+, JDK 17, Android SDK/NDK (for Android).

```bash
git clone https://github.com/mel0k1/way.git
cd way

flutter pub get
flutter build apk --release
flutter build windows --release
```

The Go core is built automatically by CI; to build it manually:

```bash
cd core
go build -tags "with_gvisor,with_quic,with_utls,with_clash_api" -o waycore.exe ./cmd/waycore
```

## Disclaimer

This project is a client shell around open-source cores. It ships no servers, no keys and no default configurations. Use it in accordance with the laws of your jurisdiction.

## License

[GPL-3.0](LICENSE) — Way depends on sing-box (GPLv3) and Xray-core.

---

<a id="way-на-русском"></a>

<p align="center"><img src="https://img.shields.io/badge/🇷🇺-Русская_версия-2E7D53" alt="RU" /></p>

## Way на русском

**Way** — кроссплатформенный VPN-клиент на **Flutter** (Material Design 3) и **Go** с двумя ядрами: [sing-box](https://github.com/SagerNet/sing-box) и [Xray-core](https://github.com/XTLS/Xray-core). Переключение между ядрами — в один тап, без реимпорта серверов.

### Возможности

- **Два ядра в одном приложении** — sing-box и xray-core, выбор движка в настройках
- **Material Design 3** — динамические палитры, скуиркл-кнопка подключения, фон с притемнёнными фигурами, тёмная и светлая темы
- **Режим TUN** — туннелирование всего трафика через VpnService на Android и системный TUN на Windows
- **Kill switch** — WFP-фаервол на Windows, Always-on VPN + блокировка без VPN на Android
- **Раздельное туннелирование** — по приложениям (Android) и по процессам (Windows)
- **Пресеты маршрутизации** — «Всё через VPN», «RU напрямую» (rule-set geosite/geoip) и блокировка рекламы (category-ads-all)
- **Редактор правил маршрутизации** — свои правила для доменов, IP и портов с действием на каждое (через VPN, напрямую, блокировать)
- **Цепочки прокси** — маршрут через выбранный сервер поверх текущего (sing-box `dialer_proxy`)
- **Трей Windows** — иконка в трее с быстрым подключением, скрытием окна в трей и иконкой-статусом
- **Плитка Android** — подключение/отключение из шторки быстрых настроек, восстановление последнего сервера
- **Бэкап и восстановление** — экспорт профилей, подписок и настроек в JSON (SAF на Android, диалог сохранения на Windows)
- **Быстрейший сервер** — urltest-группа в sing-box и реальный замер задержки через прокси (временный инстанс ядра на сервер, TCP-фолбэк) с автовыбором
- **Подписки** — импорт по ссылке или QR-коду, вставка из буфера, автообновление, совместимый с панелями User-Agent и показ квоты
- **Диплинки** — клик по ссылке `vless://`/`vmess://`/`trojan://`/`ss://`/`hysteria2://`/`tuic://` или `way://import/<url>` мгновенно импортирует профили и подписки (Android и Windows)
- **Шифрованное хранилище** — профили и ключи подписок в flutter_secure_storage (Keystore / DPAPI)
- **Автозапуск** — старт после загрузки (Android) или входа в систему (ключ Run Windows), опциональное авто-подключение при запуске
- **Кастомные уведомления** — брендированная нотификация Android с кнопкой отключения и таймером сессии, тосты Windows
- **Проверка обновлений** — сверка с GitHub Releases при старте и предложение скачать сборку
- **Интерфейс RU + EN** — следует языку системы, переключается в настройках
- **Статистика в реальном времени** — живая скорость приёма/отдачи, итоги трафика сессии и число соединений через clash API
- **NSIS-установщик** — полноценная установка на Windows с деинсталлятором и ярлыками

### Поддерживаемые протоколы

| Протокол | sing-box | xray |
| --- | :-: | :-: |
| VLESS (+ Reality, Vision, uTLS) | ✔ | ✔ |
| VMess | ✔ | ✔ |
| Trojan | ✔ | ✔ |
| Shadowsocks (вкл. 2022) | ✔ | ✔ |
| Hysteria2 | ✔ | — |
| TUIC | ✔ | — |
| Транспорты WS / gRPC / HTTP | ✔ | ✔ |

Ссылки `vless://`, `vmess://`, `trojan://`, `ss://`, `hysteria2://`, `tuic://` парсятся автоматически — по одной или целой base64-подпиской.

### Скачивание

Свежие APK и `WaySetup.exe` — в разделе [Releases](https://github.com/mel0k1/way/releases) или в артефактах CI каждого коммита.

> **Режим TUN на Windows** требует прав администратора — запускайте Way от администратора, иначе используйте режим прокси (системный прокси настраивается автоматически).

### Сборка из исходников

Нужны: Go 1.27+, Flutter 3.47+, JDK 17, Android SDK/NDK (для Android).

```bash
git clone https://github.com/mel0k1/way.git
cd way

flutter pub get
flutter build apk --release
flutter build windows --release
```

Go-ядро собирается автоматически в CI; вручную:

```bash
cd core
go build -tags "with_gvisor,with_quic,with_utls,with_clash_api" -o waycore.exe ./cmd/waycore
```

### Лицензия

[GPL-3.0](LICENSE) — Way использует sing-box (GPLv3) и Xray-core.
