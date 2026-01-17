import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jules/ui/app_container.dart';

import '../widgets/new_session_dialog.dart';

class NewSessionWindow extends StatefulWidget {
  const NewSessionWindow({super.key, required this.windowId});

  final int windowId;

  @override
  State<NewSessionWindow> createState() => _NewSessionWindowState();
}

class _NewSessionWindowState extends State<NewSessionWindow> {
  @override
  Widget build(BuildContext context) {
    return AppContainer(
      child: MaterialApp(
        home: Scaffold(
          body: NewSessionDialogWrapper(windowId: widget.windowId),
        ),
      ),
    );
  }
}

class NewSessionDialogWrapper extends StatefulWidget {
  const NewSessionDialogWrapper({super.key, required this.windowId});

  final int windowId;

  @override
  State<NewSessionDialogWrapper> createState() =>
      _NewSessionDialogWrapperState();
}

class _NewSessionDialogWrapperState extends State<NewSessionDialogWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNewSessionDialog();
    });
  }

  void _showNewSessionDialog() {
    showDialog(
      context: context,
      builder: (context) => const NewSessionDialog(),
    ).then((_) {
      final controller = WindowController.fromWindowId(widget.windowId);
      controller.close();
    });
  }

  @override
  Widget build(BuildContext context) {
    // This container can be empty because the dialog is shown above it.
    return Container();
  }
}
