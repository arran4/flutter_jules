import 'package:flutter/material.dart';
import '../../models.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'session_meta_pills.dart';
import 'package:url_launcher/url_launcher.dart';

class SessionPreviewModal extends StatelessWidget {
  final Session session;

  const SessionPreviewModal({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    SessionOutput? prOutput;
    if (session.outputs != null) {
      for (final o in session.outputs!) {
        if (o.pullRequest != null) {
          prOutput = o;
          break;
        }
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                session.title ?? "Session Preview",
                style: const TextStyle(fontSize: 18),
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
            Flexible(
              child: SelectionArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SessionMetaPills(session: session),
                      const SizedBox(height: 16),

                      // Pull Request Section (Foldable via ExpansionTile)
                      if (prOutput != null) ...[
                        Card(
                          color: Colors.purple.shade50,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            leading: const Icon(
                              Icons.merge_type,
                              color: Colors.purple,
                            ),
                            title: const Text(
                              "Pull Request Available",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      prOutput.pullRequest!.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    MarkdownBody(
                                      data: prOutput.pullRequest!.description,
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(
                                        Icons.open_in_new,
                                        size: 16,
                                      ),
                                      label: const Text("Open Pull Request"),
                                      onPressed: () => launchUrl(
                                        Uri.parse(prOutput!.pullRequest!.url),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Source Details (Foldable)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ExpansionTile(
                          title: const Text(
                            "Source Details",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          leading: const Icon(Icons.code),
                          children: [
                            ListTile(
                              title: const Text("Source"),
                              subtitle: Text(session.sourceContext.source),
                            ),
                            if (session.sourceContext.githubRepoContext !=
                                null) ...[
                              if (session.sourceContext.githubRepoContext!
                                  .startingBranch.isNotEmpty)
                                ListTile(
                                  title: const Text("Branch"),
                                  subtitle: Text(
                                    session.sourceContext.githubRepoContext!
                                        .startingBranch,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        "Prompt",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Divider(),
                      MarkdownBody(data: session.prompt, selectable: true),
                      const SizedBox(height: 16),
                      if (session.currentAction != null) ...[
                        const Text(
                          "Current Action",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(session.currentAction!),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
