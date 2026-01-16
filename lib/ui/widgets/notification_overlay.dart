import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/notification_provider.dart';
import 'github_pat_dialog.dart';

class NotificationOverlay extends StatelessWidget {
  final Widget child;

  const NotificationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.notifications.isEmpty) {
                return const SizedBox.shrink();
              }
              return Material(
                child: Column(
                  children: provider.notifications
                      .map((n) => _buildNotification(context, n))
                      .toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotification(
    BuildContext context,
    NotificationMessage notification,
  ) {
    Color backgroundColor;
    IconData icon;

    switch (notification.type) {
      case NotificationType.warning:
        backgroundColor = Colors.orange.shade100;
        icon = Icons.warning_amber_rounded;
        break;
      case NotificationType.error:
        backgroundColor = Colors.red.shade100;
        icon = Icons.error_outline;
        break;
      default:
        backgroundColor = Colors.blue.shade100;
        icon = Icons.info_outline;
    }

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(notification.message),
              ],
            ),
          ),
          if (notification.actionType != null &&
              notification.actionLabel != null)
            TextButton(
              onPressed: () {
                if (notification.actionType ==
                    NotificationActionType.showGithubPatDialog) {
                  showDialog(
                    context: context,
                    builder: (context) => const GithubPatDialog(),
                  );
                }
              },
              child: Text(notification.actionLabel!),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              Provider.of<NotificationProvider>(
                context,
                listen: false,
              ).removeNotification(notification.id);
            },
          ),
        ],
      ),
    );
  }
}
