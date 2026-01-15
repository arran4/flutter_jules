import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/auth_provider.dart';
import '../services/message_queue_provider.dart';
import '../services/session_provider.dart';
import '../services/settings_provider.dart';
import 'widgets/new_session_dialog.dart';

Future<bool> resubmitSession(
  BuildContext context,
  Session session, {
  required bool hideOriginal,
}) async {
  final NewSessionResult? result = await showDialog<NewSessionResult>(
    context: context,
    builder: (context) => NewSessionDialog(initialSession: session),
  );

  if (result == null) return false;
  if (!context.mounted) return false;

  if (result.isDraft) {
    final queueProvider = Provider.of<MessageQueueProvider>(
      context,
      listen: false,
    );
    for (final session in result.sessions) {
      queueProvider.addCreateSessionRequest(session, isDraft: true);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.sessions.length > 1 ? "Drafts saved" : "Draft saved",
        ),
      ),
    );
    return false; // No session was "successfully" created
  }

  final sessionsToCreate = result.sessions;
  bool anySucceeded = false;

  Future<void> performCreate(Session sessionToCreate) async {
    try {
      final client = Provider.of<AuthProvider>(context, listen: false).client;
      await client.createSession(sessionToCreate);
      anySucceeded = true;

      if (!context.mounted) return;

      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final sessionProvider = Provider.of<SessionProvider>(
        context,
        listen: false,
      );
      final auth = Provider.of<AuthProvider>(context, listen: false);

      switch (settings.refreshOnCreate) {
        case ListRefreshPolicy.none:
          break;
        case ListRefreshPolicy.dirty:
        case ListRefreshPolicy.watched:
          sessionProvider.refreshDirtySessions(client, authToken: auth.token!);
          break;
        case ListRefreshPolicy.quick:
          sessionProvider.fetchSessions(
            client,
            force: true,
            shallow: true,
            authToken: auth.token,
          );
          break;
        case ListRefreshPolicy.full:
          sessionProvider.fetchSessions(
            client,
            force: true,
            shallow: false,
            authToken: auth.token,
          );
          break;
      }
    } catch (e) {
      if (!context.mounted) return;
      Provider.of<MessageQueueProvider>(
        context,
        listen: false,
      ).addCreateSessionRequest(sessionToCreate, reason: 'creation_failed');
      if (sessionsToCreate.length == 1) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error Creating Session'),
            content: SelectableText(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  for (final s in sessionsToCreate) {
    await performCreate(s);
  }

  if (hideOriginal && anySucceeded) {
    if (context.mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await Provider.of<SessionProvider>(
        context,
        listen: false,
      ).toggleHidden(session.id, auth.token!);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Original session hidden.")),
        );
      }
    }
  } else if (anySucceeded) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("New session(s) created.")));
    }
  }

  return anySucceeded;
}

Future<void> handleNewSessionResultInBackground({
  required NewSessionResult result,
  required Session originalSession,
  required bool hideOriginal,
  required SessionProvider sessionProvider,
  required AuthProvider authProvider,
  required MessageQueueProvider messageQueueProvider,
  required SettingsProvider settingsProvider,
  required Function(String) showMessage,
}) async {
  if (result.isDraft) {
    for (final session in result.sessions) {
      messageQueueProvider.addCreateSessionRequest(session, isDraft: true);
    }
    showMessage(result.sessions.length > 1 ? "Drafts saved" : "Draft saved");
    return;
  }

  final sessionsToCreate = result.sessions;
  bool anySucceeded = false;

  Future<void> performCreate(Session sessionToCreate) async {
    try {
      final client = authProvider.client;
      await client.createSession(sessionToCreate);
      anySucceeded = true;

      // Refresh logic
      final settings = settingsProvider;
      switch (settings.refreshOnCreate) {
        case ListRefreshPolicy.none:
          break;
        case ListRefreshPolicy.dirty:
        case ListRefreshPolicy.watched:
          sessionProvider.refreshDirtySessions(
            client,
            authToken: authProvider.token!,
          );
          break;
        case ListRefreshPolicy.quick:
          sessionProvider.fetchSessions(
            client,
            force: true,
            shallow: true,
            authToken: authProvider.token,
          );
          break;
        case ListRefreshPolicy.full:
          sessionProvider.fetchSessions(
            client,
            force: true,
            shallow: false,
            authToken: authProvider.token,
          );
          break;
      }
    } catch (e) {
      messageQueueProvider.addCreateSessionRequest(
        sessionToCreate,
        reason: 'creation_failed',
      );
    }
  }

  for (final s in sessionsToCreate) {
    await performCreate(s);
  }

  if (hideOriginal && anySucceeded) {
    await sessionProvider.toggleHidden(originalSession.id, authProvider.token!);
    showMessage("Original session hidden.");
  } else if (anySucceeded) {
    showMessage("New session(s) created.");
  }
}

Future<void> showNewSessionDialog(BuildContext context) async {
  final result = await showDialog<NewSessionResult>(
    context: context,
    builder: (context) => const NewSessionDialog(),
  );

  if (result == null || !context.mounted) return;

  final sessionProvider = context.read<SessionProvider>();
  final authProvider = context.read<AuthProvider>();
  final messageQueueProvider = context.read<MessageQueueProvider>();
  final settingsProvider = context.read<SettingsProvider>();

  handleNewSessionResultInBackground(
    result: result,
    originalSession: Session(name: '', id: '', prompt: ''),
    hideOriginal: false,
    sessionProvider: sessionProvider,
    authProvider: authProvider,
    messageQueueProvider: messageQueueProvider,
    settingsProvider: settingsProvider,
    showMessage: (message) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    },
  );
}
