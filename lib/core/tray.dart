import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:system_tray/system_tray.dart';

import '../l10n.dart';
import 'vpn_bridge.dart';

/// Windows tray controller with a live "gauge": the icon reflects the VPN
/// phase (off / connecting amber / connected green) and the tooltip streams
/// the active server plus live throughput.
class TrayController {
  final SystemTray _tray = SystemTray();
  static const _window = MethodChannel('way/window');

  bool _inited = false;
  VpnPhase _phase = VpnPhase.stopped;
  String? _l10nCode;
  String _lastTooltip = '';
  String? _serverName;
  void Function()? _onOpen;
  void Function()? _onConnect;
  void Function()? _onDisconnect;
  void Function()? _onQuit;

  static bool get supported =>
      !kIsWeb && !Platform.isAndroid && Platform.isWindows;

  Future<void> init({
    required void Function() onOpen,
    required void Function() onConnect,
    required void Function() onDisconnect,
    required void Function() onQuit,
  }) async {
    if (!supported || _inited) return;
    _onOpen = onOpen;
    _onConnect = onConnect;
    _onDisconnect = onDisconnect;
    _onQuit = onQuit;
    try {
      await _tray.initSystemTray(
        title: 'Way',
        iconPath: _iconFor(VpnPhase.stopped),
        toolTip: 'Way',
      );
      _tray.registerSystemTrayEventHandler((event) async {
        if (event == kSystemTrayEventClick) {
          await _showWindow();
        } else if (event == kSystemTrayEventRightClick) {
          try {
            await _tray.popUpContextMenu();
          } catch (_) {}
        }
      });
      _inited = true;
    } catch (_) {}
  }

  String _iconFor(VpnPhase phase) {
    switch (phase) {
      case VpnPhase.connected:
        return 'assets/icon/way.ico';
      case VpnPhase.connecting:
      case VpnPhase.disconnecting:
        return 'assets/icon/way_wait.ico';
      case VpnPhase.stopped:
        return 'assets/icon/way_off.ico';
    }
  }

  String _tooltip(
    VpnPhase phase,
    L10n l10n,
    String? serverName,
    double? downMbps,
    double? upMbps,
  ) {
    switch (phase) {
      case VpnPhase.connected:
        final sb = StringBuffer('Way · ${l10n.connected}');
        if (serverName != null && serverName.isNotEmpty) {
          sb.write(' · $serverName');
        }
        if (downMbps != null || upMbps != null) {
          sb.write('  ·  ↓ ${_fmt(downMbps)}  ↑ ${_fmt(upMbps)} ${l10n.mbpsShort}');
        }
        return sb.toString();
      case VpnPhase.connecting:
        return 'Way · ${l10n.connecting}';
      case VpnPhase.disconnecting:
        return 'Way · ${l10n.disconnecting}';
      case VpnPhase.stopped:
        return 'Way · ${l10n.stopped}';
    }
  }

  String _fmt(double? mbps) =>
      (mbps ?? 0).toStringAsFixed(mbps != null && mbps >= 10 ? 0 : 1);

  /// Called from the app tick every ~2s. Cheap when nothing changed: the
  /// icon/menu only update on phase or locale flips, the tooltip only when
  /// its composed text differs.
  Future<void> update({
    required VpnPhase phase,
    required L10n l10n,
    String? serverName,
    double? downMbps,
    double? upMbps,
  }) async {
    if (!_inited) return;
    final phaseChanged = phase != _phase || l10n.code != _l10nCode;
    _phase = phase;
    _l10nCode = l10n.code;
    _serverName = serverName;

    final tooltip = _tooltip(phase, l10n, serverName, downMbps, upMbps);
    if (phaseChanged) {
      try {
        await _tray.setSystemTrayInfo(
          iconPath: _iconFor(phase),
          toolTip: tooltip,
        );
        _lastTooltip = tooltip;
      } catch (_) {}
      await _rebuild(l10n);
    } else if (tooltip != _lastTooltip) {
      try {
        await _tray.setSystemTrayInfo(toolTip: tooltip);
        _lastTooltip = tooltip;
      } catch (_) {}
    }
  }

  Future<void> _rebuild(L10n l10n) async {
    try {
      final serverLine = _serverName;
      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(label: l10n.trayOpen, onClicked: (_) => _onOpen?.call()),
        if (_phase == VpnPhase.connected && serverLine != null &&
            serverLine.isNotEmpty)
          MenuItemLabel(label: '· $serverLine'),
        MenuSeparator(),
        if (_phase == VpnPhase.connecting)
          MenuItemLabel(label: l10n.connecting)
        else if (_phase == VpnPhase.disconnecting)
          MenuItemLabel(label: l10n.disconnecting)
        else if (_phase == VpnPhase.connected)
          MenuItemLabel(
            label: l10n.disconnect,
            onClicked: (_) => _onDisconnect?.call(),
          )
        else
          MenuItemLabel(
            label: l10n.connect,
            onClicked: (_) => _onConnect?.call(),
          ),
        MenuSeparator(),
        MenuItemLabel(label: l10n.trayQuit, onClicked: (_) => _onQuit?.call()),
      ]);
      await _tray.setContextMenu(menu);
    } catch (_) {}
  }

  Future<void> showWindow() => _showWindow();

  Future<void> _showWindow() async {
    try {
      await _window.invokeMethod('show');
    } catch (_) {}
  }

  Future<void> setCloseToTray(bool value) async {
    if (!supported) return;
    try {
      await _window.invokeMethod('set_close_to_tray', {'value': value});
    } catch (_) {}
  }

  Future<void> quit() async {
    if (!_inited) return;
    try {
      await _tray.destroy();
    } catch (_) {}
    _inited = false;
    try {
      await _window.invokeMethod('quit');
    } catch (_) {}
  }
}
