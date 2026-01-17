import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bulk_action_preset.dart';
import '../../services/bulk_action_preset_provider.dart';
import '../screens/bulk_action_preset_manager_screen.dart';
import '../../models/filter_expression_parser.dart';
import '../../utils/action_script_parser.dart';
import 'bulk_action_progress_dialog.dart';
import '../../services/session_provider.dart';
import '../../services/message_queue_provider.dart';
import '../../models/filter_element.dart';

class BulkActionPresetDialog extends StatelessWidget {
  const BulkActionPresetDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BulkActionPresetProvider>(context);

    return AlertDialog(
      title: const Text('Run a Bulk Action Preset'),
      content: SizedBox(
        width: 500,
        height: 300,
        child: provider.presets.isEmpty
            ? const Center(
                child: Text('No presets found.'),
              )
            : ListView.builder(
                itemCount: provider.presets.length,
                itemBuilder: (context, index) {
                  final preset = provider.presets[index];
                  return ListTile(
                    title: Text(preset.name),
                    subtitle: Text(preset.description ?? 'No description'),
                    onTap: () => _runPreset(context, preset),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            final provider = context.read<BulkActionPresetProvider>();
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.push(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const BulkActionPresetManagerScreen(),
                ),
              ),
            );
          },
          icon: const Icon(Icons.settings),
          label: const Text('Manage Presets'),
        ),
      ],
    );
  }

  void _runPreset(BuildContext context, BulkActionPreset preset) {
    final filterTree = FilterExpressionParser.parse(preset.filterExpression);
    final config = ActionScriptParser.parse(preset.actionScript, filterTree);

    final sessionProvider = context.read<SessionProvider>();
    final queueProvider = context.read<MessageQueueProvider>();

    var targets = sessionProvider.items
        .where((item) {
          final session = item.data;
          final metadata = item.metadata;

          final initialState = metadata.isHidden
              ? FilterState.implicitOut
              : FilterState.implicitIn;

          if (config.filterTree == null) {
            return initialState.isIn;
          }

          final treeResult = config.filterTree!.evaluate(
            FilterContext(
              session: session,
              metadata: metadata,
              queueProvider: queueProvider,
            ),
          );

          final finalState = FilterState.combineAnd(initialState, treeResult);
          return finalState.isIn;
        })
        .map((item) => item.data)
        .toList();

    Navigator.pop(context); // Close preset dialog

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          BulkActionProgressDialog(config: config, targets: targets),
    );
  }
}
