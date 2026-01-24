import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener {
  final VoidCallback onNewSession;
  final VoidCallback onRefresh;

  TrayService({required this.onNewSession, required this.onRefresh});

  void init() {
    trayManager.addListener(this);
    setTrayIcon();
  }

  void dispose() {
    trayManager.removeListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'new_session':
        onNewSession();
        break;
      case 'show_hide':
        windowManager.isVisible().then((visible) {
          if (visible) {
            windowManager.hide();
          } else {
            windowManager.show();
          }
        });
        break;
      case 'refresh':
        onRefresh();
        break;
      case 'exit':
        windowManager.destroy();
        break;
    }
  }

  Future<void> setTrayIcon() async {
    await trayManager.setIcon(
      'assets/icon/app_icon.png',
    );
    final menu = Menu(
      items: [
        MenuItem(
          key: 'new_session',
          label: 'New Session',
        ),
        MenuItem(
          key: 'show_hide',
          label: 'Show/Hide',
        ),
        MenuItem(
          key: 'refresh',
          label: 'Refresh',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: 'Exit',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }
}
