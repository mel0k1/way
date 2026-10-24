import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:system_tray/system_tray.dart';

import '../l10n.dart';
import 'vpn_bridge.dart';

class TrayController {
  final SystemTray _tray = SystemTray();
  static const _window = MethodChannel('way/window');

  bool _inited = false;
  VpnPhase _phase = VpnPhase.stopped;
  String? _l10nCode;
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
        iconPath: 'assets/icon/way_off.ico',
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

  Future<void> update({required VpnPhase phase, required L10n l10n}) async {
    if (!_inited) return;
    if (phase == _phase && _l10nCode == l10n.code) return;
    final wasConnected = _phase == VpnPhase.connected;
    final connected = phase == VpnPhase.connected;
    _phase = phase;
    _l10nCode = l10n.code;
    if (connected != wasConnected) {
      try {
        await _tray.setSystemTrayInfo(
          iconPath: connected ? 'assets/icon/way.ico' : 'assets/icon/way_off.ico',
          toolTip: connected ? 'Way · ${l10n.connected}' : 'Way',
        );
      } catch (_) {}
    }
    await _rebuild(l10n);
  }

  Future<void> _rebuild(L10n l10n) async {
    try {
      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(label: l10n.trayOpen, onClicked: (_) => _onOpen?.call()),
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
