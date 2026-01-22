import 'package:flutter/material.dart';

class SpinnerDialog extends StatelessWidget {
  final VoidCallback? onCancel;
  final String? message;

  const SpinnerDialog({
    super.key,
    this.onCancel,
    this.message,
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
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!),
            ],
          ],
        ),
        actions: onCancel != null
            ? [
                TextButton(
                  onPressed: () {
                    // Call the cancel callback
                    onCancel!();
                    // Close the dialog
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ]
            : null,
      ),
    );
  }
}
