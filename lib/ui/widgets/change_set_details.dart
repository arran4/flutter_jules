import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models.dart';

class ChangeSetDetails extends StatelessWidget {
  final ChangeSet changeSet;
  final String? prUrl;

  const ChangeSetDetails({super.key, required this.changeSet, this.prUrl});

  @override
  Widget build(BuildContext context) {
    if (changeSet.gitPatch == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              size: 16,
              color: Colors.blueGrey,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                changeSet.source,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final gitPatch = changeSet.gitPatch!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                "Change in ${changeSet.source}",
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (prUrl != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Create PR'),
                  onPressed: () {
                    launchUrl(Uri.parse(prUrl!));
                  },
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (gitPatch.suggestedCommitMessage.isNotEmpty) ...[
          const Text(
            "Commit Message:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              gitPatch.suggestedCommitMessage,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 8),
        ],
        _PatchPreview(gitPatch: gitPatch),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PatchPreview extends StatelessWidget {
  final GitPatch gitPatch;

  const _PatchPreview({required this.gitPatch});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Patch:",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.black.withValues(alpha: 0.05),
          child: Text(
            gitPatch.unidiffPatch,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            maxLines: 15,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
