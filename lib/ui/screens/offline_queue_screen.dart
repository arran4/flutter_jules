import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/message_queue_provider.dart';
import '../../services/auth_provider.dart';

class OfflineQueueScreen extends StatelessWidget {
  const OfflineQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Offline Message Queue"),
        actions: [
          Consumer<MessageQueueProvider>(
            builder: (context, provider, _) {
              if (provider.queue.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.send),
                tooltip: "Send All Now",
                onPressed: () async {
                  final auth =
                      Provider.of<AuthProvider>(context, listen: false);
                  // Try connecting first if offline
                  if (provider.isOffline) {
                    await provider.goOnline(auth.client);
                  }

                  if (!provider.isOffline) {
                    await provider.sendQueue(auth.client, onMessageSent: (id) {
                      // Optional: feedback per message? Too noisy if many.
                    }, onError: (id, e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Error sending message: $e")));
                      }
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Queue processing finished")));
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Still offline")));
                    }
                  }
                },
              );
            },
          )
        ],
      ),
      body: Consumer<MessageQueueProvider>(
        builder: (context, provider, _) {
          if (provider.queue.isEmpty) {
            return const Center(child: Text("No queued messages"));
          }
          return ListView.builder(
            itemCount: provider.queue.length,
            itemBuilder: (context, index) {
              final msg = provider.queue[index];
              return ListTile(
                title: Text(msg.content),
                subtitle: Text(
                    "Session: ${msg.sessionId}\nCreated: ${msg.createdAt}"),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        _editMessage(context, provider, msg.id, msg.content);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        provider.deleteMessage(msg.id);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _editMessage(BuildContext context, MessageQueueProvider provider,
      String id, String currentContent) {
    final controller = TextEditingController(text: currentContent);
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Edit Message"),
              content: TextField(controller: controller, maxLines: 3),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                FilledButton(
                    onPressed: () {
                      provider.updateMessage(id, controller.text);
                      Navigator.pop(context);
                    },
                    child: const Text("Save")),
              ],
            ));
  }
}
