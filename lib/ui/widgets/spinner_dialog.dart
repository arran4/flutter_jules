import 'package:flutter/material.dart';

class SpinnerDialog extends StatelessWidget {
  final VoidCallback? onCancel;
  final String message;

  const SpinnerDialog({
    super.key,
    this.onCancel,
    this.message = "Please wait...",
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
        actions: onCancel != null
            ? [
                TextButton(
                  onPressed: onCancel,
                  child: const Text("Cancel"),
                )
              ]
            : null,
      ),
    );
  }
}
