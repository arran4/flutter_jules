import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener {
  final VoidCallback _onNewSession;
  final VoidCallback _onRefresh;

  TrayService({
    required VoidCallback onNewSession,
    required VoidCallback onRefresh,
  })  : _onNewSession = onNewSession,
        _onRefresh = onRefresh;

  Future<void> init() async {
    await trayManager.setIcon(
      Platform.isWindows
          ? 'assets/icon/app_icon.ico'
          : 'assets/icon/app_icon.png',
    );
    final List<MenuItem> items = [
      MenuItem(
        key: 'new_session',
        label: 'New Session',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'show_window',
        label: 'Show',
      ),
      MenuItem(
        key: 'hide_window',
        label: 'Hide',
      ),
      MenuItem(
        key: 'refresh',
        label: 'Refresh',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'exit_app',
        label: 'Exit',
      ),
    ];
    await trayManager.setContextMenu(Menu(items: items));
    await trayManager.setToolTip('Jules API Client');
    trayManager.addListener(this);
  }

  Future<void> destroy() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'new_session':
        _onNewSession();
        break;
      case 'show_window':
        windowManager.show();
        break;
      case 'hide_window':
        windowManager.hide();
        break;
      case 'refresh':
        _onRefresh();
        break;
      case 'exit_app':
        windowManager.destroy();
        break;
    }
  }
}
