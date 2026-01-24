import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/utils/action_script_parser.dart';
import 'package:flutter_jules/utils/action_script_builder.dart';
import 'package:flutter_jules/models/bulk_action.dart';

void main() {
  group('ActionScriptParser Tests', () {
    test('Circular Test: Build -> Parse -> Verify Config', () {
      final actions = [
        const BulkActionStep(type: BulkActionType.refreshSession),
        const BulkActionStep(type: BulkActionType.sleep, message: '5'),
      ];
      const parallelQueries = 2;
      const waitBetween = Duration(seconds: 3);
      const limit = 10;
      const offset = 5;
      const randomize = true;
      const stopOnError = true;

      // 1. Build script from config
      final script = buildActionScript(
        actions: actions,
        parallelQueries: parallelQueries,
        waitBetween: waitBetween,
        limit: limit,
        offset: offset,
        randomize: randomize,
        stopOnError: stopOnError,
      );

      // 2. Parse script back to config
      final config = ActionScriptParser.parse(script, null);

      // 3. Verify config matches original
      expect(config.actions.length, 2);
      expect(config.actions[0].type, BulkActionType.refreshSession);
      expect(config.actions[1].type, BulkActionType.sleep);
      expect(config.actions[1].message, '5');

      expect(config.parallelQueries, parallelQueries);
      expect(config.waitBetween.inSeconds, waitBetween.inSeconds);
      expect(config.limit, limit);
      expect(config.offset, offset);
      expect(config.randomize, randomize);
      expect(config.stopOnError, stopOnError);
    });

    test('Circular Test: Build -> Parse -> Re-Build -> Correctness', () {
      final actions = [const BulkActionStep(type: BulkActionType.hide)];
      const parallelQueries = 5;
      const waitBetween = Duration(seconds: 1);
      const limit = 100;
      const offset = 20;
      const randomize = false;
      const stopOnError = false;

      // 1. First build
      final script1 = buildActionScript(
        actions: actions,
        parallelQueries: parallelQueries,
        waitBetween: waitBetween,
        limit: limit,
        offset: offset,
        randomize: randomize,
        stopOnError: stopOnError,
      );

      // 2. Parse
      final config = ActionScriptParser.parse(script1, null);

      // 3. Second build from parsed config
      final script2 = buildActionScript(
        actions: config.actions,
        parallelQueries: config.parallelQueries,
        waitBetween: config.waitBetween,
        limit: config.limit,
        offset: config.offset,
        randomize: config.randomize,
        stopOnError: config.stopOnError,
      );

      // 4. Strings should be identical (assuming deterministic builder)
      expect(script2, script1);
    });

    test('Ignores comments', () {
      const script = '''
// This is a comment
SET ParallelQueries = 5; // Inline comment
# Legacy comment style

refreshSession;
''';
      final config = ActionScriptParser.parse(script, null);
      expect(config.parallelQueries, 5);
      expect(config.actions.length, 1);
      expect(config.actions[0].type, BulkActionType.refreshSession);
    });
  });
}
